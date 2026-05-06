import { builder } from '~/domain/shared/graphql/builder'
import '~/domain/shared/graphql/scalars'

import '~/domain/canvas/infrastructure/graphql/types'
import '~/domain/canvas/infrastructure/graphql/queries'

import '~/domain/image/infrastructure/graphql/enums'
import '~/domain/image/infrastructure/graphql/types'
import '~/domain/image/infrastructure/graphql/mutations'

import '~/domain/playlist/infrastructure/graphql/enums'
import '~/domain/playlist/infrastructure/graphql/types'
import '~/domain/playlist/infrastructure/graphql/inputs'
import '~/domain/playlist/infrastructure/graphql/queries'
import '~/domain/playlist/infrastructure/graphql/mutations'

import '~/domain/system/infrastructure/graphql/queries'

export const schema = builder.toSchema()
