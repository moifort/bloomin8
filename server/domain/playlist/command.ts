import { match } from 'ts-pattern'
import { CanvasCommand } from '~/domain/canvas/command'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import * as imageRepository from '~/domain/image/infrastructure/repository'
import type { Image } from '~/domain/image/types'
import { applyQuietHours, pickRandomImageId } from '~/domain/playlist/business-rules'
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
    const availableImagesId = await imageRepository.findAllIds()
    if (availableImagesId.length === 0) return 'playlist-empty' as const
    await playlistRepository.save({
      id: playlistId,
      status: 'in-progress',
      canvasUrl,
      cronIntervalInHours,
      availableImagesId,
      quietHours,
    })
    await CanvasCommand.wakeUp(canvasUrl, serverUrl)
    return playlistId
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

  export const nextImage = async (playlistId: PlaylistId = DEFAULT_PLAYLIST_ID) => {
    const playlist = await playlistRepository.findById(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    const { availableImagesId, status, cronIntervalInHours, quietHours } = playlist

    return match(status)
      .with('in-progress', async () => {
        const refilled =
          availableImagesId.length === 0 ? await imageRepository.findAllIds() : availableImagesId
        if (refilled.length === 0) return 'playlist-empty' as const
        const nextImageId = pickRandomImageId(refilled)
        const nextImage: Image | null = await imageRepository.findById(nextImageId)
        if (!nextImage) return 'image-not-found' as const
        await playlistRepository.save({
          ...playlist,
          availableImagesId: refilled.filter((id) => id !== nextImageId),
        })
        return {
          nextImage,
          displayedAt: applyQuietHours(
            new Date(Date.now() + cronIntervalInHours * 60 * 60 * 1000),
            quietHours,
          ),
        }
      })
      .with('stop', () => 'playlist-stopped' as const)
      .with('paused', () => 'playlist-paused' as const)
      .exhaustive()
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
