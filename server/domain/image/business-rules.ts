import type { ImageId } from '~/domain/image/types'

// Ids to delete so that only `keepImagesId` remain. Returns null when none of
// the ids to keep exists: replacing the album with nothing is never intended
// (a failed upload), so the caller must refuse rather than wipe everything.
export const imagesToDeleteForKeeping = (
  allImagesId: ImageId[],
  keepImagesId: ImageId[],
): ImageId[] | null => {
  const keep = new Set(keepImagesId)
  if (!allImagesId.some((id) => keep.has(id))) return null
  return allImagesId.filter((id) => !keep.has(id))
}
