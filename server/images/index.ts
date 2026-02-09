import type { Image } from '~/images/types'

export const saveImage = async (raw: string, orientation: 'P' | 'L') => {
  const storage = useStorage('images')
  const id = crypto.randomUUID()
  const image: Image = {
    id,
    raw,
    orientation,
    addedAt: new Date(),
    url: `/images/${id}.jpeg`,
  }
  await storage.setItem<Image>(id, image)
  return image
}

export const getImage = async (id: string) => {
  const storage = useStorage('images')
  const image = await storage.getItem<Image>(id)
  if (!image) return 'not-found' as const
  return image
}
