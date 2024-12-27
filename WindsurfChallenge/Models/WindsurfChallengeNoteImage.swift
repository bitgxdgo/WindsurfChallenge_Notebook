import Foundation
import CoreData

@objc(WindsurfChallengeNoteImage)
public class WindsurfChallengeNoteImage: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var position: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: WindsurfChallengeNote?
}

extension WindsurfChallengeNoteImage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WindsurfChallengeNoteImage> {
        return NSFetchRequest<WindsurfChallengeNoteImage>(entityName: "NoteImage")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}

extension WindsurfChallengeNoteImage: Identifiable { }
