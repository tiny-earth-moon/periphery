---
description: Every kind of result outskirts reports, from unused declarations to Metal functions, with a before and after example for each and the option that enables it.
---

# Analysis

outskirts reports the _declarations_ that lie beyond every entry point of your project. A declaration is a `class`, `struct`, `protocol`, `function`, `property`, `constructor`, `enum`, `typealias`, `associatedtype` and so on. outskirts builds your project to produce the index store, turns it into a graph of what refers to what, marks the entry points (see [Framework conventions and retention](framework-conventions.md)), then walks the graph from those roots: whatever the walk never reaches is reported.

Beyond simple unreferenced declarations, outskirts can find more subtle cases, described below. Most analyses run by default; a few are opt-in, because they are newer, noisier or only useful to some projects. Each opt-in section says how to enable it. Every option is listed in the [options reference](options.md).

## Result kinds

Each result carries an annotation, which is also the kind you give to `report_exclude` (see [Excluding results](excluding-files.md#excluding-results)).

| Annotation | Enabled by | Section |
|------------|------------|---------|
| `unused` | default | [Unused declarations](#unused-declarations) |
| `assignOnlyProperty` | default | [Assign-only properties](#assign-only-properties) |
| `unassignedOptionalProperty` | `--enable-unassigned-optional-analysis` | [Unassigned optional properties](#unassigned-optional-properties) |
| `enumCaseNeverConstructed` | `--enable-unconstructed-enum-case-analysis` | [Unconstructed enum cases](#unconstructed-enum-cases) |
| `redundantProtocol` | default | [Redundant protocols](#redundant-protocols) |
| `redundantPublicAccessibility` | default | [Redundant public accessibility](#redundant-public-accessibility) |
| `redundantOpenAccessibility` | `--enable-open-final-analysis` | [Open and final](#open-and-final) |
| `missingFinal` | `--enable-open-final-analysis` | [Open and final](#open-and-final) |
| `redundantAccessLevel` | `--enable-redundant-access-level-analysis` | [Redundant access levels](#redundant-access-levels) |
| `emptyExtension` | `--enable-empty-extension-analysis` | [Empty extensions](#empty-extensions) |
| `superfluousIgnoreCommand` | default | [Superfluous ignore comments](#superfluous-ignore-comments) |
| `unusedAssetCatalogColor` | `--detect-unused-asset-catalog-colors` | [Asset catalog colors](#asset-catalog-colors) |
| `unusedAssetCatalogImage` | `--detect-unused-asset-catalog-images` | [Asset catalog images](#asset-catalog-images) |
| `missingMetalFunction` | `--detect-unused-metal-functions` | [Metal functions](#metal-functions) |

Unused parameters, imports, localized strings and Metal functions are `unused` results; the JSON `kind` field tells them apart (`var.parameter`, `module`, `localized_string`, `metal_function`), and a `report_exclude` kind can be narrowed with it, e.g. `unused.var.parameter`.

## Unused declarations

The simplest result: a declaration that nothing references, such as a `class` that is no longer used anywhere in your codebase. The message reads `Unused class 'LegacyCache'`.

Before:

```swift
final class LegacyCache { // Unused class 'LegacyCache'
    func purge() {}
}

struct Store {
    func load() -> [String] { [] }
}
```

After:

```swift
struct Store {
    func load() -> [String] { [] }
}
```

Members are reported on their own when their type is used but they are not, and a type reported as a whole does not repeat its members.

## Function parameters

outskirts finds unused function parameters. Parameters of protocol requirements and of overridden methods are handled with care, as explained below.

Before:

```swift
func greet(name: String, locale: String) { // 'locale' is unused
    print("Hello " + name)
}
```

After:

```swift
func greet(name: String) {
    print("Hello " + name)
}
```

To keep parameters that callers must pass anyway, see [Unused parameters without a default value](framework-conventions.md#unused-parameters-without-a-default-value). To keep a parameter on purpose, use `// outskirts:ignore:parameters` (see [Comment commands](comment-commands.md)).

### Protocol function parameters

An unused parameter of a protocol function is only reported if it is also unused in all implementations.

```swift
protocol Greeter {
    func greet(name: String)
    func farewell(name: String) // 'name' is unused
}

class InformalGreeter: Greeter {
    func greet(name: String) {
        print("Sup " + name + ".")
    }

    func farewell(name: String) { // 'name' is unused
        print("Cya.")
    }
}
```

> [!TIP]
> You can ignore all unused parameters of protocols and their conforming functions with [`--retain-unused-protocol-func-params`](options.md).

### Overrides

Similar to protocols, parameters of overridden functions are only reported if they are also unused in the base function and all overriding functions.

```swift
class BaseGreeter {
    func greet(name: String) {
        print("Hello.")
    }

    func farewell(name: String) { // 'name' is unused
        print("Goodbye.")
    }
}

class InformalGreeter: BaseGreeter {
    override func greet(name: String) {
        print("Sup " + name + ".")
    }

    override func farewell(name: String) { // 'name' is unused
        print("Cya.")
    }
}
```

### Foreign protocols and classes

Unused parameters of protocols or classes defined in foreign modules (e.g. Foundation) are always ignored, since you do not have access to modify the base function declaration.

### fatalError functions

Unused parameters of functions that simply call `fatalError` are also ignored. Such functions are often unimplemented required initializers in subclasses.

```swift
class Base {
    let param: String

    required init(param: String) {
        self.param = param
    }
}

class Subclass: Base {
    init(custom: String) {
        super.init(param: custom)
    }

    required init(param: String) {
        fatalError("init(param:) has not been implemented")
    }
}
```

## Generic type parameters

An unused generic parameter of a function or method is reported.

Before:

```swift
func describe<T, U>(_ value: T) -> String { // 'U' is unused
    String(describing: value)
}
```

After:

```swift
func describe<T>(_ value: T) -> String {
    String(describing: value)
}
```

The generic parameters of a `struct`, `class`, `enum` or `actor` are not reported by default, because a parameter that appears in no member is often deliberate: a phantom type distinguishes specializations at compile time (`Tagged<UserTag>`, typed identifiers, units, state machines), and removing it breaks every specialization. The opt-in [`--report-unused-type-parameters`](options.md) (`report_unused_type_parameters: true`) reports them as well:

```swift
// 'Tag' is reported only with --report-unused-type-parameters
struct Tagged<Tag> {
    let raw: Int
}
```

## Redundant protocols

A protocol that is conformed to by an object is not truly used unless it is also used as an existential type, or to specialize a generic method or class. outskirts identifies such redundant protocols, whether one or several types conform to them. The result is `redundantProtocol`, and each conformance is listed as a related location (`Redundant protocol conformance 'MyProtocol'`).

Before:

```swift
protocol MyProtocol { // 'MyProtocol' is redundant
    func someMethod()
}

// 'MyProtocol' conformance is redundant
class MyClass1: MyProtocol {
    func someMethod() {
        print("Hello from MyClass1!")
    }
}

// 'MyProtocol' conformance is redundant
class MyClass2: MyProtocol {
    func someMethod() {
        print("Hello from MyClass2!")
    }
}

let myClass1 = MyClass1()
myClass1.someMethod()

let myClass2 = MyClass2()
myClass2.someMethod()
```

Although both implementations of `someMethod` are called, at no point does an object take on the type of `MyProtocol`. The protocol itself is redundant, and there is no benefit in `MyClass1` or `MyClass2` conforming to it.

After:

```swift
class MyClass1 {
    func someMethod() {
        print("Hello from MyClass1!")
    }
}

class MyClass2 {
    func someMethod() {
        print("Hello from MyClass2!")
    }
}
```

Just like the methods and properties of an object, individual requirements of a used protocol can be identified as unused:

```swift
protocol MyProtocol {
    var usedProperty: String { get }
    // 'unusedProperty' is unused
    var unusedProperty: String { get }
}

class MyConformingClass: MyProtocol {
    var usedProperty: String = "used"
    // 'unusedProperty' is unused
    var unusedProperty: String = "unused"
}

class MyClass {
    let conformingClass: MyProtocol

    init() {
        conformingClass = MyConformingClass()
    }

    func perform() {
        print(conformingClass.usedProperty)
    }
}

let myClass = MyClass()
myClass.perform()
```

Here `MyProtocol` is itself used and cannot be removed. However, since `unusedProperty` is never called on `MyConformingClass`, outskirts can tell that the declaration of `unusedProperty` in `MyProtocol` is unused too, and can be removed along with its implementation.

## Enumerations

Along with unused enumerations, outskirts identifies individual unused enum cases.

Before:

```swift
enum Direction {
    case north
    case south
    case diagonal // Unused enum element 'diagonal'
}
```

After:

```swift
enum Direction {
    case north
    case south
}
```

Plain enums that are not raw representable, i.e. that _don't_ have a `String`, `Character`, `Int` or floating-point raw value type, can be reliably analysed. Enumerations that _do_ have a raw value type can be built dynamically, and are therefore assumed to be used:

```swift
enum MyEnum: String {
    case myCase
}

func someFunction(value: String) {
    if let myEnum = MyEnum(rawValue: value) {
        somethingImportant(myEnum)
    }
}
```

There is no direct reference to `myCase`, so it is reasonable to expect it _might_ no longer be needed. However, if it were removed, `somethingImportant` would never be called when `someFunction` is passed `"myCase"`.

## Assign-only properties

Properties that are assigned but never read are reported as `assignOnlyProperty`, with the message `Assign-only property 'name' is assigned, but never used`.

Before:

```swift
class MyClass {
    // 'assignOnlyProperty' is assigned, but never used
    var assignOnlyProperty: String

    init(value: String) {
        self.assignOnlyProperty = value
    }
}
```

After:

```swift
class MyClass {
    init(value: String) {}
}
```

Sometimes this is intended, for example a property that keeps an object alive. You then have a few options:

- Retain individual properties with [comment commands](comment-commands.md).
- Retain all assign-only properties of some types with [`--retain-assign-only-property-types`](options.md). The types must match their exact use in the property declaration (without the optional question mark), e.g. `String`, `[String]`, `Set<String>`. outskirts cannot resolve inferred property types, so you may need to add explicit type annotations to your properties.
- Disable the analysis entirely with [`--retain-assign-only-properties`](options.md).

```swift
final class Session {
    // outskirts:ignore - keeps the observer alive
    var observer: NSObjectProtocol
}
```

## Unassigned optional properties

Opt-in: [`--enable-unassigned-optional-analysis`](options.md), key `enable_unassigned_optional_analysis: true`.

The symmetric case of assign-only properties: optional properties that are read but never assigned, and are therefore always `nil`. Results use the `unassignedOptionalProperty` kind, with the message `Optional property 'someVar' is never assigned (always nil)`.

Before:

```swift
class MyClass {
    // Optional property 'someVar' is never assigned
    var someVar: Int?

    func someFunc() {
        print(someVar)
    }
}
```

After:

```swift
class MyClass {
    func someFunc() {
        print(nil as Int?)
    }
}
```

Only stored `var` properties declared with an optional type (`T?`, `T!`, `Optional<T>`) and no initial value other than `nil` are considered. Writes are taken from the index: assignments, `self.x = …` in closures, `inout` arguments, and a writable key path used directly as `object[keyPath: \.name] = …`. A property assigned anywhere is not reported.

Properties that may be assigned in ways the index does not record are never reported:

- properties referenced by a key path that is stored or passed on (`\.name` as an argument or in a variable, e.g. `assign(to:on:)`), as it may be written through;
- properties with an attribute (`@IBOutlet`, `@NSManaged`, `@objc`, property wrappers…);
- `weak`, `unowned`, `dynamic`, `lazy` or `override` properties;
- Objective-C accessible properties;
- properties of types conforming to `Codable`/`Decodable` or `NSCoding`;
- protocol requirements, and retained properties (including [comment commands](comment-commands.md)).

Properties of structs with a synthesized memberwise initializer are considered assigned by it.

## Unconstructed enum cases

Since 3.22.0.

Opt-in: [`--enable-unconstructed-enum-case-analysis`](options.md), key `enable_unconstructed_enum_case_analysis: true`.

An enum case that is only matched in patterns, and never constructed, can never be produced: the case and the branches that match it are dead. Results use the `enumCaseNeverConstructed` kind, with the message `Enum case 'retrying' is only matched, never constructed`.

Before:

```swift
enum Phase {
    case idle
    // Enum case 'retrying' is only matched, never constructed
    case retrying
}

func label(_ phase: Phase) -> String {
    switch phase {
    case .idle: "Idle"
    case .retrying: "Retrying"
    }
}
```

After:

```swift
enum Phase {
    case idle
}

func label(_ phase: Phase) -> String {
    switch phase {
    case .idle: "Idle"
    }
}
```

A case is reported when every reference to it is the case pattern of a `switch` case, of an `if`, `guard` or `while case` condition, of a `for case` loop or of a `catch` clause: `.name`, `Type.name`, `.name(let value)`, `let .name(value)`, `.name?`, or a case nested in a tuple or in the pattern of another case. Any other reference counts as a construction, including a comparison (`state == .name`), a default argument, a return value, a closure, an interpolation or a function value (`Phase.name`).

Enums whose cases may be produced without a visible construction are never analyzed:

- raw representable, `CaseIterable`, `Codable`/`Decodable` and `CodingKey` enums, and `@objc` enums;
- enums conforming to a protocol from another, unindexed module, other than `Equatable`, `Hashable`, `Comparable`, `Error`, `Sendable`, `Identifiable` and a few others without static requirements;
- cases that satisfy a static requirement of a protocol (`static var fallback: Self`);
- enums with a custom attribute, such as a macro, and public enums when [`--retain-public`](options.md) or `--retain-public-modules` retains them;
- enums that a custom `~=` operator can receive, and every enum when a generic `~=` operator is declared;
- cases whose name is written in an `#if` block, which may construct them in a branch that was not compiled.

Retained cases (including [comment commands](comment-commands.md)) are not reported.

## Redundant public accessibility

Declarations marked `public` that are not referenced from outside their home module have redundant public accessibility: the `public` modifier can be removed. The result is `redundantPublicAccessibility`, with the message `Redundant public accessibility for function 'f' (not used outside of MyModule)`. Removing it has a couple of benefits:

- It reduces the public surface area of your modules.
- In [Whole Module Compilation](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst#whole-module-optimizations-wmo) mode, Swift can infer `final` by [automatically discovering](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst#advice-if-wmo-is-enabled-use-internal-when-a-declaration-does-not-need-to-be-accessed-outside-of-module) all potentially overriding declarations. `final` classes are [better optimized](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst#advice-use-final-when-you-know-the-declaration-does-not-need-to-be-overridden) by the compiler.

Before:

```swift
// In module Core, used only inside Core
public func normalize(_ s: String) -> String { // redundant
    s.lowercased()
}
```

After:

```swift
func normalize(_ s: String) -> String {
    s.lowercased()
}
```

This analysis can be disabled with [`--disable-redundant-public-analysis`](options.md).

### Public members

By default, the explicit `public` members of a `public` type or extension that is itself referenced from outside its module are not checked, since it is common to publish a set of members before they are all used. The opt-in [`--enable-redundant-public-members`](options.md) (`enable_redundant_public_members: true`) reports those members too: a member explicitly marked `public` (methods, initializers, properties, subscripts, nested types) that is not referenced from outside its module has redundant public accessibility, following the same rules as top-level declarations (references from files that `@testable import` the module do not count). Members of `open` classes are checked too.

```swift
public struct Formatter {
    public init() {}
    // reported with --enable-redundant-public-members
    public func debugDump() {}
}
```

The following members are never reported, because their accessibility is required or their use cannot be observed:

- `open` members, overrides and `required` initializers.
- Protocol requirement implementations, including those of external protocols (`Equatable`, `CustomStringConvertible`, `Codable`…), as recorded by the index.
- `@inlinable` and `@usableFromInline` members, and members referenced from a public `@inlinable` function.
- Members of `@propertyWrapper`, `@resultBuilder` and `@dynamicMemberLookup` types.
- Implicit members (synthesized `Codable` conformance, memberwise initializers), `enum` cases, type aliases and associated types.
- Members whose type appears in another public declaration's signature.

Members that are implicitly public because their extension is marked `public` (`public extension T { func f() }`) are not reported: the modifier to remove is the extension's.

## Open and final

Opt-in: [`--enable-open-final-analysis`](options.md), key `enable_open_final_analysis: true`.

This analysis reports two kinds of results:

- `redundantOpenAccessibility`: a class or member marked `open` that is never subclassed or overridden outside its home module, so it could be `public`. An `open` member of a class that is not itself `open` is always reported, as it cannot be overridden outside the module.
- `missingFinal`: a `public` or `internal` class that is never subclassed, or a member that is never overridden, so it could be `final`. Members of a class reported as a whole are not reported again, and constants, initializers, static members, actors and declarations already `final` are ignored. Objective-C accessible declarations are ignored with `--retain-objc-accessible`, as are `dynamic` members.

Before:

```swift
// Class 'Renderer' is open but never subclassed
// outside its module
open class Renderer {
    open func draw() {}
}

class Cache { // Class 'Cache' could be final
    func clear() {}
}
```

After:

```swift
public class Renderer {
    public func draw() {}
}

final class Cache {
    func clear() {}
}
```

Subclasses and overrides are read from the index store, which only describes the scanned modules. A subclass or override declared by an unscanned client module cannot be observed, therefore `redundantOpenAccessibility` is only reliable when every module that uses the `open` declarations is scanned, and it is skipped entirely with `--retain-public`. Subclasses and overrides declared in files that `@testable import` the home module do not count as being outside of it, as they only need `public` accessibility.

Either kind can be excluded with `report_exclude`, e.g. `**/Generated/**:missingFinal`.

## Redundant access levels

Opt-in: [`--enable-redundant-access-level-analysis`](options.md), key `enable_redundant_access_level_analysis: true`.

This analysis reports `redundantAccessLevel` results: explicit access modifiers identical to the access level the declaration would get without them, i.e. the default of its enclosing context. Removing such a modifier does not change the access level of the declaration. The message names the redundant modifier and the context it repeats, e.g. `Redundant internal access level for function 'load' (already the default at the top level)`.

Before:

```swift
internal func load() {} // redundant internal

fileprivate struct Token {
    fileprivate let raw: String // redundant fileprivate
}
```

After:

```swift
func load() {}

fileprivate struct Token {
    let raw: String
}
```

| Declaration | Context | Reported |
|-------------|---------|----------|
| `internal` declaration or extension | top level | yes |
| `fileprivate` or `private` declaration | top level | no (no enclosing modifier; both mean file scope) |
| `internal` member | `open`, `public` or `internal` type (explicit or implicit) | yes |
| `public` member | `public` or `open` type | no (members of a `public` type default to `internal`) |
| `private` or `fileprivate` member | `internal` type | no (narrower than the default) |
| `fileprivate` member | `private` or `fileprivate` top-level type, or a type nested in one without modifier | yes |
| `private` member | `private` or `fileprivate` type | no (restricts access to the type's declarations, narrower than file scope) |
| any member | `private` nested type | no (its members default to the enclosing scope, which no modifier expresses) |
| member with the extension's modifier (`public`, `internal`, `fileprivate`, `private`) | extension with that modifier | yes |
| `fileprivate` member | `private` extension | yes (members of a `private` extension are `fileprivate`) |
| `private` member | `fileprivate` extension | no (narrower than the default) |
| `internal` member | `public` extension | no |
| member | extension without modifier | like a member of the extended type; extensions of external types are treated like extensions of a `public` type |
| `open` declaration or member | any | never (see [Open and final](#open-and-final)) |
| setter modifier (`private(set)`, `internal(set)`…) | any | never; only the getter modifier (`public` in `internal(set) public var`) is checked |
| protocol requirement, `enum` case | any | never (they cannot carry an access modifier) |
| member of a `package` type or extension | any | never (the `package` access level is not modelled) |

A member of a `private` extension marked `private` is reported although, strictly, it stays visible to the extended type's declarations in the file only: the extension already confines it to the file, which is the intended scope in practice. Results of unused declarations are not repeated, and results can be excluded with `report_exclude`, e.g. `**/Generated/**:redundantAccessLevel`.

## Empty extensions

Opt-in: [`--enable-empty-extension-analysis`](options.md), key `enable_empty_extension_analysis: true`.

This analysis reports `emptyExtension` results: extensions that declare neither a member nor a conformance, such as `extension Foo {}`. Removing them does not change the program. The message reads `Empty extension of 'Foo'` and the JSON `kind` is `extension`.

Before:

```swift
struct Foo {}

extension Foo {} // Empty extension of 'Foo'

extension Foo {
    // TODO: helpers
}
```

After:

```swift
struct Foo {}
```

| Extension | Reported |
|-----------|----------|
| `extension Foo {}`, with or without a `where` clause | yes |
| body containing only comments | yes |
| body containing only `#if` blocks whose clauses are all empty | yes |
| `@available` attribute only | yes |
| conformance (`extension Foo: Bar {}`), even with an empty body | never |
| at least one member, including in one clause of an `#if` block | never |
| any other attribute (an attached macro can add members or conformances) | never |
| preceded by `// outskirts:ignore`, in a file with `// outskirts:ignore:all`, or in a file matched by `retain_files` | never |

The index store has no record of an extension without members or conformances, so this analysis reads the syntax of the indexed source files instead. As a consequence, an extension is judged on its source text only: the members a macro expansion or another `#if` configuration would produce are unknown, and `// outskirts:ignore` is the way to keep an extension that is empty on purpose. Results can be excluded with `report_exclude`, e.g. `**/Generated/**:emptyExtension`.

## Unused imports

outskirts reports imports of scanned modules that a file does not use, as `unused` results of kind `module`. The analysis can be turned off with [`--disable-unused-import-analysis`](options.md) (`disable_unused_import_analysis: true`), and modules kept with [`--retain-unused-imported-modules`](options.md) (`retain_unused_imported_modules`).

Before:

```swift
import CoreKit
import NetworkKit // Unused import 'NetworkKit'

let store = CoreKit.Store()
```

After:

```swift
import CoreKit

let store = CoreKit.Store()
```

outskirts can only detect unused imports of targets it has scanned. It cannot detect unused imports of other targets, because their Swift source files are unavailable and uses of `@_exported` cannot be observed. `@_exported` changes the public interface of a target, so that the declarations it exports are no longer necessarily declared by the imported target. For example, `Foundation` exports `Dispatch`, among others: if a file imports `Foundation` and references `DispatchQueue` but no other declaration of `Foundation`, the `Foundation` import cannot be removed, as it would also make `DispatchQueue` unavailable. To avoid false positives, outskirts therefore only detects unused imports of the targets it has scanned, unless system imports are enabled.

### System framework imports

Opt-in: [`--enable-unused-system-imports`](options.md), key `enable_unused_system_imports: true` (experimental).

By default, imports of system frameworks (`Foundation`, `UIKit`, `SwiftUI`, `Combine`, …) are not analysed. This option extends the analysis to them, using the system modules that the compiler indexes alongside your code (the `isSystem` units of the index store):

- The module declaring each referenced system declaration is read from the index store records of the system modules, and from the module name mangled into Swift USRs (`s:10Foundation3URLV`).
- Every module a system module depends on in the index store is treated as possibly re-exported by it, along with a short list of known re-exports (`Foundation` exports `Dispatch`, `Darwin`, `CoreFoundation` and `ObjectiveC`; `UIKit` and `AppKit` export `Foundation`; `SwiftUI` exports `SwiftUICore`; `Cocoa` exports `AppKit`, `Foundation` and `CoreData`). An import is therefore not reported when another imported framework may provide it, nor when the file uses a module the import may re-export: importing both `UIKit` and `Foundation` and using only `URL` reports neither.
- A file referencing any declaration whose module cannot be determined has none of its system imports analysed.
- System imports are only analysed when the index store contains the system modules. A store built without them (for example with `-index-ignore-system-modules`) reports no system import.

Before:

```swift
import Combine // Unused import 'Combine'
import Foundation

let url = URL(string: "https://example.com")
```

After:

```swift
import Foundation

let url = URL(string: "https://example.com")
```

Limitations: uses that leave no reference in the index store are invisible, such as `@objc` or `dynamic` without any other Objective-C runtime reference, so a file whose only use of `Foundation` is an `@objc` attribute is reported. Use `// outskirts:ignore` on the import, or `retain_unused_imported_modules`, for such cases.

### Mixed Swift and Objective-C targets

outskirts will likely produce false positives for targets with mixed Swift and Objective-C, as it cannot scan the Objective-C files. For projects with a significant amount of Objective-C, disable unused import detection with `--disable-unused-import-analysis` (`disable_unused_import_analysis: true`), or exclude the mixed language targets from the results (see [Excluding results](excluding-files.md#excluding-results)).

```yaml
disable_unused_import_analysis: true
```

See also [Platform conditionals](framework-conventions.md#platform-conditionals), which keeps the imports of modules used only on another platform.

## Superfluous ignore comments

Enabled by default; [`--superfluous-ignore-comments`](options.md) (`superfluous_ignore_comments`, default `true`) controls it, and `--no-superfluous-ignore-comments` turns it off.

An ignore comment on a declaration that is in fact referenced ignores nothing. It is reported as `superfluousIgnoreCommand`, with the message `Superfluous ignore comment for class 'Theme' (declaration is referenced and should not be ignored)`, so that ignore comments do not outlive the reason they were added.

Before:

```swift
// outskirts:ignore
final class Theme {} // superfluous: Theme is used below

let theme = Theme()
```

After:

```swift
final class Theme {}

let theme = Theme()
```

## Unused localized strings

Enabled by default; [`--disable-unused-localized-string-analysis`](options.md) (`disable_unused_localized_string_analysis: true`) turns it off.

outskirts identifies unused keys of String Catalog (`.xcstrings`) files, reported as `unused` results of kind `localized_string`. Catalogues are discovered from Xcode target resources (including synchronized folders), SwiftPM target `resources` and the `xcstrings` key of a generic project configuration (see [Getting started](getting-started.md)).

Before, with a catalogue that holds `welcome.title` and `welcome.subtitle`:

```swift
// Localizable.xcstrings: "welcome.subtitle" is unused
Text("welcome.title")
```

After, the `welcome.subtitle` key is removed from the catalogue, or put back to use:

```swift
Text("welcome.title")
Text("welcome.subtitle")
```

### How a key is found

A key is considered used when a static string literal with the same value is:

- Passed to a parameter of type `LocalizedStringKey`, `LocalizedStringResource`, `String.LocalizationValue`, `DisplayRepresentation` or `IntentDescription` (including optionals, arrays and variadics). The parameter type is resolved from the index store, so this covers SwiftUI initializers and modifiers (`Text`, `Button`, `Label`, `Toggle`, `Section`, `navigationTitle`, ...), `String(localized:)`, as well as your own functions and initializers. A literal passed to a plain `String` parameter (e.g. `Label("title", systemImage: "star")`'s `systemImage`) is not considered a key.
- Passed to `NSLocalizedString`, `Bundle.localizedString(forKey:)`, `LocalizedStringKey(_:)`, `LocalizedStringResource(_:)` or `Text(_:)`, matched by name.
- Assigned to, returned from, or used as the default value of a declaration annotated with one of the types above (e.g. `static let title: LocalizedStringResource = "key"`). Returned literals include the branches of `switch` and `if` statements or expressions, ternaries and closures of a function, computed property or closure whose return type is one of the types above. Elements of tuple, array and dictionary literals are matched against the element types of the declaration (e.g. only `"title"` in `let item: (LocalizedStringKey, String) = ("title", "star")`).

An interpolated literal is matched to the format key Foundation derives from it: `Text("Hello \(name)")` uses the key `Hello %@`. Since the type of the interpolated value is not known, each format specifier is treated as a wildcard, so the catalogue keys `Hello %@`, `Hello %lld` and `Hello %1$lf` are all considered used. A literal `%` in an interpolated literal is escaped as `%%`, as Foundation does.

When the called function cannot be resolved (e.g. calling a closure, an enum case constructor or an Objective-C method), the literals passed to it are conservatively considered keys. Ternaries, tuple, array and dictionary literals, `if`/`switch` expressions and closure bodies are looked through.

### Generated symbols

Keys referenced through the symbols Xcode 26+ generates for a catalogue (`STRING_CATALOG_GENERATE_SYMBOLS`, e.g. `Text(.settingsTitle)` or `String(localized: .itemCount(3))`) are detected: outskirts reads the generated `GeneratedStringSymbols_<Table>.swift` files (even inside `index_exclude` build directories) to map each symbol to its key, and a key is used when its symbol is referenced. When a referenced symbol cannot be mapped (e.g. its generated file was deleted after the build), a warning names it and its key is only considered used if a string literal references it, as without generated symbols; no catalogue is retained as a whole.

### Keys built at runtime

A key built at runtime and passed to `NSLocalizedString`, `Bundle.localizedString(forKey:)`, `LocalizedStringKey(_:)`, `LocalizedStringResource(_:)` or `String.LocalizationValue(_:)` (a variable, a concatenation, an interpolation passed to a plain `String` key, or a ternary with a non-literal branch) cannot be matched to a catalogue key. Instead of reporting the keys it may look up, outskirts retains the catalogue keys starting with its literal prefix: `NSLocalizedString("settings." + name, comment: "")` and `NSLocalizedString("settings.\(name)", comment: "")` retain `settings.*`. With `bundle: .module` (or `Bundle.module.localizedString(forKey:)`), only the catalogues of the calling module are affected; with any other bundle, every catalogue is. Catalogue ownership comes from SwiftPM target membership; catalogues of other project types have no known owner and are matched against the runtime keys of every module. `--verbose` lists each runtime key call site.

A key without a literal prefix (e.g. a central helper such as `String(localized: String.LocalizationValue(key))`) may be any key, so it retains nothing: a warning names each such call site, and the keys it looks up are reported unless they are referenced elsewhere or declared with `localized_string_key_patterns`. The [`--retain-runtime-localized-keys`](options.md) option (`retain_runtime_localized_keys: true`, disabled by default) instead retains every key of the catalogues such a lookup may reach, which hides every unused key of these catalogues.

### Excluding catalogues

Catalogues matching the [`--localized-string-catalog-exclude`](options.md) globs (`localized_string_catalog_exclude`) are not analysed. By default `**/InfoPlist.xcstrings` and `**/AppShortcuts.xcstrings` are excluded, since their keys are consumed by the system rather than referenced from Swift source. Setting the option replaces the default list, so include these patterns if you add your own:

```yaml
localized_string_catalog_exclude:
  - "**/InfoPlist.xcstrings"
  - "**/AppShortcuts.xcstrings"
  - "**/DefaultCategories.xcstrings"
```

### Key patterns

Keys built at runtime (e.g. `String(localized: String.LocalizationValue("quickChat.\(id)"))`) can be declared with [`--localized-string-key-patterns`](options.md) (`localized_string_key_patterns`). Each pattern is either a glob, where `*` matches any characters and `?` a single character, or a regular expression between slashes. Patterns must match the whole key, and catalogue keys matching any of them are considered used:

```yaml
localized_string_key_patterns:
  - "quickChat.*"
  - "/^tier\.(gold|silver|bronze)\.label$/"
```

### Literal matching

Codebases that pass keys around as plain `String` values (e.g. `titleKey: String`, a `switch` returning a `String` key, tuples) can enable [`--localized-string-key-literal-match`](options.md) (`localized_string_key_literal_match: true`, disabled by default). Any string literal in the source whose value, after decoding escapes, equals a catalogue key then marks that key as used, whatever its type or position. Literals with interpolation are not considered, and test targets are skipped when `--exclude-tests` is set.

> [!WARNING]
> Matching is by value only, so an incidental literal (e.g. `"title"`, `"OK"`) that happens to equal a dead key hides it. Prefer typing keys as `LocalizedStringResource` (or `LocalizedStringKey`), which outskirts detects precisely, and reserve this option for code that cannot be migrated.

> [!NOTE]
> Apart from generated symbols, only string literals are detected, and keys are matched regardless of the `table:`/`bundle:` arguments. Keys passed around as values (e.g. `String(localized: value)` where `value` is a `String.LocalizationValue` built elsewhere) are only detected where the value is created from a literal. Declare keys used only through such values with `localized_string_key_patterns`, keep them in a dedicated catalogue excluded with `localized_string_catalog_exclude`, or, where possible, refactor dynamic keys to use conditional expressions with static literals:
>
> ```swift
> var message: String {
>     if condition {
>         String(localized: "message_success")
>     } else {
>         String(localized: "message_failure")
>     }
> }
> ```

## Asset catalog colors

Opt-in: [`--detect-unused-asset-catalog-colors`](options.md), key `detect_unused_asset_catalog_colors: true`.

Xcode generates a Swift symbol for each color of an asset catalog (`ColorResource.accent`, `Color.accent`, `UIColor.accent`, ...) in a `GeneratedAssetSymbols.swift` file under DerivedData, which the default `--index-exclude` patterns exclude. This option indexes these files despite `--index-exclude` and reports the colors that are never used.

A color is used when any of its generated symbols is used, or when its name is referenced as a string: a string literal in the scanned Swift sources (e.g. `Color("Brand")` or `UIColor(named: "Brand")`), a named color of an Interface Builder file, or the global accent color (the `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` build setting of Xcode projects, `AccentColor` when no build setting names it).

An unused color is reported once as `unusedAssetCatalogColor`, with its asset name and the `.colorset` directories found in the `*.xcassets` catalogs under the project directory (no path is given when none declares it). Every other declaration of the generated file is retained, and the file is left out of unused import analysis. Results are located in the generated file under DerivedData; the `.colorset` paths point to the asset to remove.

Before, with `Brand.colorset` and `Legacy.colorset` in `Assets.xcassets`:

```swift
// Unused asset catalog color 'Legacy'
// (Assets.xcassets/Legacy.colorset)
let tint = Color(.brand)
```

After, `Legacy.colorset` is removed from the catalog:

```swift
let tint = Color(.brand)
```

To skip these results, use `--report-exclude "**/GeneratedAssetSymbols.swift:unusedAssetCatalogColor"`.

## Asset catalog images

Opt-in: [`--detect-unused-asset-catalog-images`](options.md), key `detect_unused_asset_catalog_images: true`.

Images are detected the same way as colors, independently of them: Xcode generates `ImageResource.logo` and the `UIImage.logo` and `NSImage.logo` accessors for each image and symbol image of an asset catalog. An image is used when any of its generated symbols is used (e.g. `Image(.logo)` or `UIImage.logo`), or when its name is referenced as a string: a string literal in the scanned Swift sources (e.g. `Image("Logo")`, `UIImage(named: "Logo")` or `NSImage(named: "Logo")`), an image of an Interface Builder file (`image`, `backgroundImage`, `selectedImage`, ... attributes and `<image name="Logo">` resources), or an Info.plist value of `UILaunchScreen`'s `UIImageName`, `UIApplicationShortcutItemIconFile` or `CFBundleIconName`. App icon sets (`.appiconset`) have no generated symbol and are never reported.

An unused image is reported once as `unusedAssetCatalogImage`, with its asset name and the `.imageset` or `.symbolset` directories found in the `*.xcassets` catalogs under the project directory.

Before:

```swift
// Unused asset catalog image 'OldBanner'
// (Assets.xcassets/OldBanner.imageset)
Image(.logo)
```

After, `OldBanner.imageset` is removed from the catalog:

```swift
Image(.logo)
```

To skip these results, use `--report-exclude "**/GeneratedAssetSymbols.swift:unusedAssetCatalogImage"`.

Limits: an image loaded with a name built at runtime (e.g. `UIImage(named: "flag-\(code)")`), or referenced only from a file that is not scanned (a widget or app extension target outside the scanned schemes, a storyboard or Info.plist that the project driver does not collect, a SwiftPM resource bundle without generated symbols), is reported as unused. Scan every target that uses the catalog, or exclude these results with `--report-exclude`.

## Metal functions

Opt-in: [`--detect-unused-metal-functions`](options.md), key `detect_unused_metal_functions: true`.

outskirts reads the `.metal` files under the project root that `--index-exclude` does not exclude (hidden directories, `*.build`, `DerivedData`, `SourcePackages`, `Pods`, `Carthage` and `node_modules` are not searched) and finds the functions the app looks up by name: those qualified with `kernel`, `vertex` or `fragment`, or attributed with `[[visible]]`, `[[stitchable]]`, `[[mesh]]`, `[[object]]` or `[[intersection(...)]]` (named by their `[[host_name("...")]]` when they have one). Plain helper functions are never reported.

A function is used when a Swift string literal names it as the `name:` argument of `makeFunction(name:)` (and its `constantValues:` variants) or of `MTLFunctionStitchingFunctionNode(name:)`, or is assigned to `MTLFunctionDescriptor.name`. Two result kinds are reported:

- `unused` with the kind `metal_function`: a Metal function that no Swift literal names, located in its `.metal` file.
- `missingMetalFunction`: a Swift literal naming a Metal function that no `.metal` file declares, located at the literal (`Metal function 'blurr' not found in any .metal file`).

Before:

```swift
// Shaders.metal declares kernel functions
// 'blur' and 'sharpen'; 'sharpen' is unused.
let blur = library.makeFunction(name: "blurr")
// Metal function 'blurr' not found in any .metal file
```

After, the typo is fixed and `sharpen` is removed from `Shaders.metal`:

```swift
let blur = library.makeFunction(name: "blur")
```

A name that is not a plain string literal (a variable, an interpolation) may name any function, so it retains every Metal function. The reader is lightweight, it does not compile the shaders: functions of `#if` blocks are known but never reported, and when a macro may declare functions, no `missingMetalFunction` is reported. No `missingMetalFunction` is reported either when the project has no `.metal` file.

A library that is not built from the project's `.metal` files may declare any function, so as soon as a Swift source creates one, no `missingMetalFunction` is reported at all (the `unused` results are unchanged). The calls that count are `makeLibrary(source:)` (with or without `options:`), `makeLibrary(URL:)`, `makeLibrary(filepath:)`, `makeLibrary(data:)`, `makeLibrary(stitchedDescriptor:)`, `makeBinaryArchive(` and any use of `MTLBinaryArchive`; `makeLibrary()` and `makeDefaultLibrary()` read the compiled project library and do not. `--verbose` prints the first such call and says why literals naming unknown functions are left out.

Known limits: functions declared in `.h` headers or inside C++ namespaces are not read, so a literal naming one is reported as not found, unless a library created at run time is present.
