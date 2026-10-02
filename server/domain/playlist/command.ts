import { match } from 'ts-pattern'
import { CanvasCommand } from '~/domain/canvas/command'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import * as imageRepository from '~/domain/image/infrastructure/repository'
import {
  applyQuietHours,
  pickNextImage,
  shownFromRemaining,
} from '~/domain/playlist/business-rules'
import * as playlistRepository from '~/domain/playlist/infrastructure/repository'
import { DEFAULT_PLAYLIST_ID } from '~/domain/playlist/primitives'
import type { PlaylistId, QuietHours } from '~/domain/playlist/types'
import type { Hour } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const log = createLogger('playlist')

export namespace PlaylistCommand {
  export const start = async (
    serverUrl: ServerUrl,
    canvasUrl: CanvasUrl,
    cronIntervalInHours: Hour,
    quietHours?: QuietHours,
    playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
  ) => {
    const allImagesId = await imageRepository.findAllIds()
    if (allImagesId.length === 0) return 'playlist-empty' as const
    await playlistRepository.save({
      id: playlistId,
      status: 'in-progress',
      canvasUrl,
      cronIntervalInHours,
      shownImagesId: [],
      quietHours,
      // The device pulls right away when woken; until then nothing is scheduled.
      nextPullAt: undefined,
    })
    let wokeUp = false
    try {
      await CanvasCommand.wakeUp(canvasUrl, serverUrl)
      wokeUp = true
    } catch (error) {
      log.warn('canvas unreachable on start, will start at next natural pull', error)
    }
    return { playlistId, wokeUp }
  }

  export const updateInterval = async (
    cronIntervalInHours: Hour,
    playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
  ) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    await playlistRepository.save({ ...playlist, cronIntervalInHours })
    return playlistId
  }

  // Answers a device pull: the image to show (if any) and when to pull next.
  // The next pull time is stored so the app can show it and detect a device
  // that missed its wake-up.
  export const nextImage = async (playlistId: PlaylistId = DEFAULT_PLAYLIST_ID) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    const { shownImagesId, lastImageId, status, cronIntervalInHours, quietHours } = playlist
    const nextPullAt = applyQuietHours(
      new Date(Date.now() + cronIntervalInHours * 60 * 60 * 1000),
      quietHours,
    )

    const outcome = await match(status)
      .with('in-progress', async () => {
        const picked = pickNextImage({
          allImagesId: await imageRepository.findAllIds(),
          shownImagesId,
          lastImageId,
        })
        if (!picked) return { kind: 'empty' as const }
        // Null only if the image was deleted between listing and reading.
        const image = await imageRepository.findById(picked.nextImageId)
        if (!image) return { kind: 'empty' as const }
        return { kind: 'show' as const, image, shownImagesId: picked.shownImagesId }
      })
      .with('paused', () => ({ kind: 'paused' as const }))
      .exhaustive()

    if (outcome.kind === 'show') {
      await playlistRepository.save({
        ...playlist,
        shownImagesId: outcome.shownImagesId,
        lastImageId: outcome.image.id,
        nextPullAt,
      })
      return { kind: 'show' as const, image: outcome.image, nextPullAt }
    }
    await playlistRepository.save({ ...playlist, nextPullAt })
    return { kind: outcome.kind, nextPullAt }
  }

  // One-shot upgrade of a playlist stored with the legacy remaining-ids list.
  export const migrateLegacyCycle = async (playlistId: PlaylistId = DEFAULT_PLAYLIST_ID) => {
    const remaining = await playlistRepository.findLegacyRemainingImagesId(playlistId)
    const playlist = remaining && (await playlistRepository.findById(playlistId))
    if (!remaining || !playlist) return false
    const allImagesId = await imageRepository.findAllIds()
    await playlistRepository.save({
      ...playlist,
      shownImagesId: shownFromRemaining(allImagesId, remaining),
    })
    return true
  }

  export const updateQuietHours = async (
    quietHours: QuietHours,
    playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
  ) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    await playlistRepository.save({ ...playlist, quietHours })
    return playlistId
  }

  export const pause = async (playlistId: PlaylistId = DEFAULT_PLAYLIST_ID) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    if (playlist.status !== 'in-progress') return 'not-playing' as const
    await playlistRepository.save({ ...playlist, status: 'paused' })
    return playlistId
  }

  export const resume = async (
    serverUrl: ServerUrl,
    playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
  ) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    if (playlist.status !== 'paused') return 'not-paused' as const
    await playlistRepository.save({ ...playlist, status: 'in-progress' })
    let wokeUp = false
    try {
      await CanvasCommand.wakeUp(playlist.canvasUrl, serverUrl)
      wokeUp = true
    } catch (error) {
      log.warn('canvas unreachable on resume, will resume at next natural pull', error)
    }
    return { playlistId, wokeUp }
  }
}
