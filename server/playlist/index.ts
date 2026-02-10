import { match } from 'ts-pattern'
import { Canvas } from '~/canvas/index'
import type { CanvasUrl, Hour, ServerUrl } from '~/config/types'
import { Images } from '~/images/index'
import type { ImageId } from '~/images/types'
import { PlaylistId } from '~/playlist/primitives'
import type { Playlist as PlaylistType } from '~/playlist/type'

export namespace Playlist {
  export const start = async (
    canvasUrl: CanvasUrl,
    serverUrl: ServerUrl,
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    await Canvas.wakeUp(canvasUrl, serverUrl)
    const storage = useStorage('playlist')
    await storage.setItem<PlaylistType>(playlistId, {
      id: playlistId,
      status: 'started',
      availableImagesId: await Images.getAllImagesId(),
    })
    return playlistId
  }

  export const nextImage = async (
    cronIntervalInHours: Hour,
    playlistId = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4'),
  ) => {
    const storage = useStorage('playlist')
    const playlist = await storage.getItem<PlaylistType>(playlistId)
    if (!playlist) return 'playlist-not-found' as const
    const { availableImagesId, status } = playlist
    return await match(status)
      .with('started', async () => {
        if (availableImagesId.length === 0) return 'playlist-empty' as const
        const nextImageId = getRandomImageId(availableImagesId)
        const nextImage = await Images.getById(nextImageId)
        if (nextImage === 'not-found') return 'image-not-found' as const
        await storage.setItem<PlaylistType>(playlistId, {
          ...playlist,
          status: 'in-progress',
          availableImagesId: availableImagesId.filter((id) => id !== nextImageId),
        })
        return { nextImage, displayedAt: new Date() }
      })
      .with('in-progress', async () => {
        if (availableImagesId.length === 0) {
          // Loop
          await storage.setItem<PlaylistType>(playlistId, {
            ...playlist,
            availableImagesId: await Images.getAllImagesId(),
          })
        }
        const nextImageId = getRandomImageId(availableImagesId)
        const nextImage = await Images.getById(nextImageId)
        if (nextImage === 'not-found') return 'image-not-found' as const
        await storage.setItem<PlaylistType>(playlistId, {
          ...playlist,
          availableImagesId: availableImagesId.filter((id) => id !== nextImageId),
        })
        return {
          nextImage,
          displayedAt: new Date(Date.now() + cronIntervalInHours * 60 * 60 * 1000),
        }
      })
      .with('stop', () => 'playlist-stopped' as const)
      .exhaustive()
  }

  const getRandomImageId = (availableImagesId: ImageId[]) => {
    if (availableImagesId.length === 0) throw new Error('availableImagesId must not be empty')
    if (availableImagesId.length === 1) return availableImagesId[0]
    const randomIndex = Math.floor(Math.random() * availableImagesId.length)
    return availableImagesId[randomIndex]
  }
}
