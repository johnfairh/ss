//
//  Map.swift
//  Sass
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/main/LICENSE
//

/// A Sass map value.
///
/// Sass maps -- dictionaries --  are immutable.
///
/// When a map is viewed as a Sass list then the list is of two-element lists, one
/// for each key-value pair in the map.  The pairs are in no particular order.
///
/// Sass requires that the empty map is equal to all empty arrays.  Be careful
/// using them as dictionary keys.
public final class SassMap: SassValue {
    public override var separator: SassList.Separator {
        // Following dart-sass...
        dictionary.count == 0 ? .undecided : .comma
    }

    /// The dictionary of values.
    public let dictionary: [SassValue : SassValue]

    /// Create a `SassMap` from an existing `Dictionary`.
    public init(_ dictionary: [SassValue: SassValue]) {
        self.dictionary = dictionary
    }

    /// Create a  `SassMap` from a sequence of (`SassValue`, `SassValue`) pairs.
    ///
    /// The program crashes if the keys are not unique.
    public init<S>(uniqueKeysWithValues keysAndValues: S)
    where S : Sequence, S.Element == (SassValue, SassValue) {
        self.dictionary = .init(uniqueKeysWithValues: keysAndValues)
    }

    override var listCount: Int { dictionary.count }

    /// - warning: this method uses `sassIndex` to numerically index into the list representation of
    ///   this map.  To access the map via its keys use `subscript(_:)` or `dictionary` directly.
    public override func valueAt(sassIndex: SassValue) throws -> SassValue {
        // This is barely useful so don't bother making it efficient
        let arrayIndex = try arrayIndexFrom(sassIndex: sassIndex)
        return Array(self)[arrayIndex]
    }

    /// Return the value corresponding to the given key, or `nil` if the map does not have the key.
    public subscript(_ key: SassValue) -> SassValue? {
        dictionary[key]
    }

    /// An iterator for contents of the map.  Each element of the iteration is a `SassList`
    /// containing the key and value `SassValue`s for one entry in the map.
    public override func makeIterator() -> AnyIterator<SassValue> {
        let list: [SassValue] = dictionary.map { SassList([$0.key, $0.value]) }
        return AnyIterator(list.makeIterator())
    }

    public override func accept<V, R>(visitor: V) throws -> R where V : SassValueVisitor, R == V.ReturnType {
        try visitor.visit(map: self)
    }

    public override var description: String {
        "Map(\(Array(self)))"
    }

    /// List equality: two `SassMap`s are equal if their maps are equivalent.
    public static func == (lhs: SassMap, rhs: SassMap) -> Bool {
        lhs.dictionary == rhs.dictionary
    }

    /// Hashes the map's contents
    public override func hash(into hasher: inout Hasher) {
        hasher.combine(dictionary)
        // see `SassList.hash(into:)` for list-map equiv issues
    }
}

extension SassValue {
    /// Reinterpret the value as a map.  Empty lists are reinterpreted as the empty map.
    /// - throws: `SassTypeError` if it isn't a map or empty list.
    public func asMap() throws -> SassMap {
        if let selfMap = self as? SassMap {
            return selfMap
        }
        if let selfList = self as? SassList,
           selfList.listCount == 0 {
            return SassMap([:])
        }
        throw SassValueError.wrongType(expected: "SassMap", actual: self)
    }
}