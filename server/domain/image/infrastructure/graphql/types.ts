import type { Image } from '~/domain/image/types'
import { builder } from '~/domain/shared/graphql/builder'
import { OrientationEnum } from './enums'

export const ImageType = builder.objectRef<Image>('Image').implement({
  description: 'A picture stored in the playlist',
  fields: (t) => ({
    id: t.expose('id', { type: 'ImageId', description: 'Unique identifier (UUID v4)' }),
    url: t.expose('url', {
      type: 'ImageUrl',
      description: 'Server-relative path served as a JPEG (e.g. /images/<id>_P.jpg)',
    }),
    orientation: t.expose('orientation', {
      type: OrientationEnum,
      description: 'How the device should display the image',
    }),
    createdAt: t.expose('createdAt', {
      type: 'DateTime',
      description: 'Server-side upload timestamp',
    }),
  }),
})
