import Foundation
import SwiftData

enum DataStoreFactory {
    static let cloudContainerIdentifier = "iCloud.JIANGJINGZHE.Billow"
    static let appGroupIdentifier = BillowSharedStore.appGroupIdentifier

    struct Result {
        let container: ModelContainer
        let usesCloudKit: Bool
    }

    static func makeContainer() -> Result {
        let schema = billowSchema

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return makeLocalContainer(schema: schema, usesAppGroup: false)
        }

        BillowSharedStore.migrateLegacyDefaultsIfNeeded()
        let cloudConfiguration = sharedConfiguration(schema: schema, usesCloudKit: true)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BillowMigrationPlan.self,
                configurations: [cloudConfiguration]
            )
            BillowSharedStore.defaults.set(true, forKey: BillowSharedStore.Keys.usesCloudKit)
            BillowSharedStore.defaults.removeObject(forKey: BillowSharedStore.Keys.cloudKitFallbackReason)
            return Result(container: container, usesCloudKit: true)
        } catch {
            BillowSharedStore.defaults.set(error.localizedDescription, forKey: BillowSharedStore.Keys.cloudKitFallbackReason)
            return makeLocalContainer(schema: schema, usesAppGroup: true)
        }
    }

    static func makeExtensionContainer() throws -> ModelContainer {
        let usesCloudKit = BillowSharedStore.defaults.object(forKey: BillowSharedStore.Keys.usesCloudKit) as? Bool ?? true
        let preferred = sharedConfiguration(schema: billowSchema, usesCloudKit: usesCloudKit)
        do {
            return try ModelContainer(
                for: billowSchema,
                migrationPlan: BillowMigrationPlan.self,
                configurations: [preferred]
            )
        } catch {
            let fallback = sharedConfiguration(schema: billowSchema, usesCloudKit: !usesCloudKit)
            return try ModelContainer(
                for: billowSchema,
                migrationPlan: BillowMigrationPlan.self,
                configurations: [fallback]
            )
        }
    }

    static var billowSchema: Schema {
        Schema(BillowSchemaV1.models)
    }

    private static func sharedConfiguration(schema: Schema, usesCloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            "Billow",
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: usesCloudKit ? .private(cloudContainerIdentifier) : .none
        )
    }

    private static func makeLocalContainer(schema: Schema, usesAppGroup: Bool) -> Result {
        let localConfiguration = ModelConfiguration(
            "Billow",
            schema: schema,
            groupContainer: usesAppGroup ? .identifier(appGroupIdentifier) : .none,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BillowMigrationPlan.self,
                configurations: [localConfiguration]
            )
            if usesAppGroup {
                BillowSharedStore.defaults.set(false, forKey: BillowSharedStore.Keys.usesCloudKit)
            }
            return Result(
                container: container,
                usesCloudKit: false
            )
        } catch {
            fatalError("Unable to initialize Billow's data store: \(error)")
        }
    }
}

/// Version the first released schema so later model changes can be introduced
/// through an explicit migration stage instead of relying on implicit behavior.
enum BillowSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Bill.self, PaymentRecord.self, PaymentMethod.self]
    }
}

enum BillowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BillowSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
