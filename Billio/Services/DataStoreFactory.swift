import Foundation
import SwiftData

enum DataStoreFactory {
    static let cloudContainerIdentifier = "iCloud.JIANGJINGZHE.Billio"
    static let appGroupIdentifier = BillioSharedStore.appGroupIdentifier

    struct Result {
        let container: ModelContainer
        let usesCloudKit: Bool
    }

    static func makeContainer() -> Result {
        let schema = billioSchema

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return makeLocalContainer(schema: schema, usesAppGroup: false)
        }

        BillioSharedStore.migrateLegacyDefaultsIfNeeded()
        let cloudConfiguration = sharedConfiguration(schema: schema, usesCloudKit: true)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BillioMigrationPlan.self,
                configurations: [cloudConfiguration]
            )
            BillioSharedStore.defaults.set(true, forKey: BillioSharedStore.Keys.usesCloudKit)
            BillioSharedStore.defaults.removeObject(forKey: BillioSharedStore.Keys.cloudKitFallbackReason)
            return Result(container: container, usesCloudKit: true)
        } catch {
            BillioSharedStore.defaults.set(error.localizedDescription, forKey: BillioSharedStore.Keys.cloudKitFallbackReason)
            return makeLocalContainer(schema: schema, usesAppGroup: true)
        }
    }

    static func makeExtensionContainer() throws -> ModelContainer {
        let usesCloudKit = BillioSharedStore.defaults.object(forKey: BillioSharedStore.Keys.usesCloudKit) as? Bool ?? true
        let preferred = sharedConfiguration(schema: billioSchema, usesCloudKit: usesCloudKit)
        do {
            return try ModelContainer(
                for: billioSchema,
                migrationPlan: BillioMigrationPlan.self,
                configurations: [preferred]
            )
        } catch {
            let fallback = sharedConfiguration(schema: billioSchema, usesCloudKit: !usesCloudKit)
            return try ModelContainer(
                for: billioSchema,
                migrationPlan: BillioMigrationPlan.self,
                configurations: [fallback]
            )
        }
    }

    static var billioSchema: Schema {
        Schema(BillioSchemaV1.models)
    }

    private static func sharedConfiguration(schema: Schema, usesCloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            "Billio",
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: usesCloudKit ? .private(cloudContainerIdentifier) : .none
        )
    }

    private static func makeLocalContainer(schema: Schema, usesAppGroup: Bool) -> Result {
        let localConfiguration = ModelConfiguration(
            "Billio",
            schema: schema,
            groupContainer: usesAppGroup ? .identifier(appGroupIdentifier) : .none,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BillioMigrationPlan.self,
                configurations: [localConfiguration]
            )
            if usesAppGroup {
                BillioSharedStore.defaults.set(false, forKey: BillioSharedStore.Keys.usesCloudKit)
            }
            return Result(
                container: container,
                usesCloudKit: false
            )
        } catch {
            fatalError("Unable to initialize Billio's data store: \(error)")
        }
    }
}

/// Version the first released schema so later model changes can be introduced
/// through an explicit migration stage instead of relying on implicit behavior.
enum BillioSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Bill.self, PaymentRecord.self, PaymentMethod.self]
    }
}

enum BillioMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BillioSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
