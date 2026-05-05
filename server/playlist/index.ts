import { consola } from 'consola'
import { match } from 'ts-pattern'
import { Canvas } from '~/canvas/index'
import type { CanvasUrl, Hour, ServerUrl } from '~/config/types'
import { Images } from '~/images/index'
import type { ImageId } from '~/images/types'
import { PlaylistId } from '~/playlist/primitives'
import type { Playlist as PlaylistType, QuietHours } from '~/playlist/type'

export namespace Playlist {
  export const start = async (
    serverUrl: ServerUrl,
    canvasUrl: CanvasUrl,
    cronIntervalInHours: Hour,
    quietHours?: QuietHours,
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const availableImagesId = await Images.getAllImagesId()
    if (availableImagesId.length === 0) return 'playlist-empty' as const
    await storage.setItem<PlaylistType>(playlistId, {
      id: playlistId,
      status: 'in-progress',
      canvasUrl,
      cronIntervalInHours,
      availableImagesId,
      quietHours,
    })
    await Canvas.wakeUp(canvasUrl, serverUrl)
    return playlistId
  }

  export const nextImage = async (
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    const { availableImagesId, status, cronIntervalInHours, quietHours } = playlist
    return await match(status)
      .with('in-progress', async () => {
        const ifEmptyLoopAvailableImagesId =
          availableImagesId.length === 0 ? await Images.getAllImagesId() : availableImagesId
        if (ifEmptyLoopAvailableImagesId.length === 0) return 'playlist-empty' as const
        const nextImageId = getRandomImageId(ifEmptyLoopAvailableImagesId)
        const nextImage = await Images.getById(nextImageId)
        if (nextImage === 'not-found') return 'image-not-found' as const
        await storage.setItem<PlaylistType>(playlistId, {
          ...playlist,
          availableImagesId: ifEmptyLoopAvailableImagesId.filter((id) => id !== nextImageId),
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

  export const pause = async (playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4')) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    if (playlist.status !== 'in-progress') return 'not-playing' as const
    await storage.setItem<PlaylistType>(playlistId, { ...playlist, status: 'paused' })
    return playlistId
  }

  export const resume = async (
    serverUrl: ServerUrl,
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    if (playlist.status !== 'paused') return 'not-paused' as const
    await storage.setItem<PlaylistType>(playlistId, { ...playlist, status: 'in-progress' })
    let wokeUp = false
    try {
      await Canvas.wakeUp(playlist.canvasUrl, serverUrl)
      wokeUp = true
    } catch (error) {
      consola
        .withTag('playlist')
        .warn('canvas unreachable on resume, will resume at next natural pull', error)
    }
    return { playlistId, wokeUp }
  }

  export const updateInterval = async (
    cronIntervalInHours: Hour,
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    await storage.setItem<PlaylistType>(playlistId, { ...playlist, cronIntervalInHours })
    return playlistId
  }

  const applyQuietHours = (date: Date, quietHours?: QuietHours): Date => {
    if (!quietHours?.enabled) return date

    const { timezone, start, end } = quietHours

    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
    }).formatToParts(date)

    const hour = Number.parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10)
    const minute = Number.parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10)

    // Outside quiet window → no change
    if (hour >= end && hour < start) return date

    // Compute time until `end` (7h)
    const hoursUntilEnd = hour >= start ? 24 - hour + end : end - hour
    const msUntilEnd = (hoursUntilEnd * 60 - minute) * 60 * 1000

    return new Date(date.getTime() + msUntilEnd)
  }

  export const getProgress = async (
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    const totalImages = await Images.getAllImagesId()
    const remaining = playlist.availableImagesId.length
    const total = totalImages.length
    return {
      displayed: total - remaining,
      total,
      status: playlist.status,
    }
  }

  const getRandomImageId = (availableImagesId: ImageId[]) => {
    if (availableImagesId.length === 0) throw new Error('availableImagesId must not be empty')
    if (availableImagesId.length === 1) return availableImagesId[0]
    const randomIndex = Math.floor(Math.random() * availableImagesId.length)
    return availableImagesId[randomIndex]
  }
}
