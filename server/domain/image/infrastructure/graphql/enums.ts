import { builder } from '~/domain/shared/graphql/builder'

export const OrientationEnum = builder.enumType('Orientation', {
  description: 'Image display orientation as transmitted to the BLOOMIN8 device',
  values: {
    portrait: { value: 'P', description: 'Portrait — stored as-is, displayed upright' },
    landscape: {
      value: 'L',
      description: 'Landscape — stored portrait, device rotates 90° counter-clockwise on display',
    },
  } as const,
})
