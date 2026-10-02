import { config } from '~/domain/config'
import { ImageCommand } from '~/domain/image/command'
import { PlaylistCommand } from '~/domain/playlist/command'
import { createLogger } from '~/system/logger'
import { runMigrations } from '~/system/migrations'

export default defineNitroPlugin(() => {
  const log = createLogger('startup')
  log.info('Runtime config', config())
  runMigrations(async () => {
    const migratedImages = await ImageCommand.migrateInlineRaw()
    if (migratedImages > 0) log.info(`Moved ${migratedImages} images to JPEG files`)
    if (await PlaylistCommand.migrateLegacyCycle()) {
      log.info('Playlist migrated to shownImagesId, current cycle kept')
    }
  })
})
