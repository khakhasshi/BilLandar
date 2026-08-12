import Foundation
import SwiftData

enum DataStoreFactory {
    static let cloudContainerIdentifier = "iCloud.JIANGJINGZHE.BilLandar"
    static let appGroupIdentifier = BilLandarSharedStore.appGroupIdentifier

    struct Result {
        let container: ModelContainer
        let usesCloudKit: Bool
    }

    static func makeContainer() -> Result {
        let schema = billandarSchema

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return makeLocalContainer(schema: schema, usesAppGroup: false)
        }

        BilLandarSharedStore.migrateLegacyDefaultsIfNeeded()
        let cloudConfiguration = sharedConfiguration(schema: schema, usesCloudKit: true)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BilLandarMigrationPlan.self,
                configurations: [cloudConfiguration]
            )
            BilLandarSharedStore.defaults.set(true, forKey: BilLandarSharedStore.Keys.usesCloudKit)
            BilLandarSharedStore.defaults.removeObject(forKey: BilLandarSharedStore.Keys.cloudKitFallbackReason)
            return Result(container: container, usesCloudKit: true)
        } catch {
            BilLandarSharedStore.defaults.set(error.localizedDescription, forKey: BilLandarSharedStore.Keys.cloudKitFallbackReason)
            return makeLocalContainer(schema: schema, usesAppGroup: true)
        }
    }

    static func makeExtensionContainer() throws -> ModelContainer {
        let usesCloudKit = BilLandarSharedStore.defaults.object(forKey: BilLandarSharedStore.Keys.usesCloudKit) as? Bool ?? true
        let preferred = sharedConfiguration(schema: billandarSchema, usesCloudKit: usesCloudKit)
        do {
            return try ModelContainer(
                for: billandarSchema,
                migrationPlan: BilLandarMigrationPlan.self,
                configurations: [preferred]
            )
        } catch {
            let fallback = sharedConfiguration(schema: billandarSchema, usesCloudKit: !usesCloudKit)
            return try ModelContainer(
                for: billandarSchema,
                migrationPlan: BilLandarMigrationPlan.self,
                configurations: [fallback]
            )
        }
    }

    static var billandarSchema: Schema {
        Schema(BilLandarSchemaV1.models)
    }

    private static func sharedConfiguration(schema: Schema, usesCloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            "BilLandar",
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: usesCloudKit ? .private(cloudContainerIdentifier) : .none
        )
    }

    private static func makeLocalContainer(schema: Schema, usesAppGroup: Bool) -> Result {
        let localConfiguration = ModelConfiguration(
            "BilLandar",
            schema: schema,
            groupContainer: usesAppGroup ? .identifier(appGroupIdentifier) : .none,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BilLandarMigrationPlan.self,
                configurations: [localConfiguration]
            )
            if usesAppGroup {
                BilLandarSharedStore.defaults.set(false, forKey: BilLandarSharedStore.Keys.usesCloudKit)
            }
            return Result(
                container: container,
                usesCloudKit: false
            )
        } catch {
            fatalError("Unable to initialize BilLandar's data store: \(error)")
        }
    }
}

/// Version the first released schema so later model changes can be introduced
/// through an explicit migration stage instead of relying on implicit behavior.
enum BilLandarSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Bill.self, PaymentRecord.self, PaymentMethod.self]
    }
}

enum BilLandarMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BilLandarSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
