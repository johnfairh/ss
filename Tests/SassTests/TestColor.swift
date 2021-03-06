//
//  TestColor.swift
//  SassTests
//
//  Copyright 2020 swift-sass contributors
//  Licensed under MIT (https://github.com/johnfairh/swift-sass/blob/main/LICENSE
//

import XCTest
@testable import Sass // color implementation bits

func XCTAssertHslIntEqual(_ lhs: HslColor, _ rhs: HslColor) {
    XCTAssertEqual(Int(lhs.hue.rounded()), Int(rhs.hue.rounded()))
    XCTAssertEqual(Int(lhs.saturation.rounded()), Int(rhs.saturation.rounded()))
    XCTAssertEqual(Int(lhs.lightness.rounded()), Int(rhs.lightness.rounded()))
}

class TestColor: XCTestCase {
    let rgbBlack = try! RgbColor(red: 0, green: 0, blue: 0)
    let hslBlack = try! HslColor(hue: 0, saturation: 0, lightness: 0)

    let rgbRed = try! RgbColor(red: 255, green: 0, blue: 0)
    let hslRed = try! HslColor(hue: 0, saturation: 100, lightness: 50)

    let rgbGreen = try! RgbColor(red: 0, green: 255, blue: 0)
    let hslGreen = try! HslColor(hue: 120, saturation: 100, lightness: 50)

    let rgbBlue = try! RgbColor(red: 0, green: 0, blue: 255)
    let hslBlue = try! HslColor(hue: 240, saturation: 100, lightness: 50)

    let rgbPink = try! RgbColor(red: 246, green: 142, blue: 227)
    let hslPink = try! HslColor(hue: 311, saturation: 85, lightness: 76)

    // carefully pick colors that don't suffer los along the trip :(

    private func checkConversion(_ rgb: RgbColor, _ hsl: HslColor) {
        XCTAssertHslIntEqual(hsl, HslColor(rgb))
        XCTAssertEqual(rgb, RgbColor(hsl))
    }

    func testRgbHslConversion() throws {
        checkConversion(rgbBlack, hslBlack)
        checkConversion(rgbRed, hslRed)
        checkConversion(rgbGreen, hslGreen)
        checkConversion(rgbBlue, hslBlue)
        checkConversion(rgbPink, hslPink)
    }

    func testRangeChecking() throws {
        do {
            let col = try SassColor(red: -1, green: 0, blue: 0)
            XCTFail("Bad color \(col)")
        } catch {
            print(error)
        }
        do {
            let col = try SassColor(red: 0, green: 0, blue: 0, alpha: 100)
            XCTFail("Bad color \(col)")
        } catch {
            print(error)
        }
        do {
            let col = try SassColor(hue: 100, saturation: 200, lightness: 0.8)
            XCTFail("Bad color \(col)")
        } catch {
            print(error)
        }
        do {
            let col = try SassColor(hue: -20, saturation: 20, lightness: 0.8)
            XCTFail("Bad color \(col)")
        } catch {
            print(error)
        }
    }

    private func check(rgb colRgb: SassColor, _ r: Int, _ g: Int, _ b: Int, _ a: Double) {
        XCTAssertEqual(r, colRgb.red)
        XCTAssertEqual(g, colRgb.green)
        XCTAssertEqual(b, colRgb.blue)
        XCTAssertEqual(a, colRgb.alpha)
    }

    private func check(hsl colHsl: SassColor, _ h: Double, _ s: Double, _ l: Double, _ a: Double) {
        XCTAssertEqual(h, colHsl.hue)
        XCTAssertEqual(s, colHsl.saturation)
        XCTAssertEqual(l, colHsl.lightness)
        XCTAssertEqual(a, colHsl.alpha)
    }

    func testValueBehaviours() throws {
        let colRgb = try SassColor(red: 12, green: 20, blue: 100, alpha: 0.5)
        check(rgb: colRgb, 12, 20, 100, 0.5)
        XCTAssertEqual("Color(RGB(12, 20, 100) alpha 0.5)", colRgb.description)

        let colHsl = try SassColor(hue: 190, saturation: 20, lightness: 95, alpha: 0.9)
        check(hsl: colHsl, 190, 20, 95, 0.9)
        XCTAssertEqual("Color(HSL(190.0°, 20.0%, 95.0%) alpha 0.9)", colHsl.description)

        let val: SassValue = colRgb
        XCTAssertNoThrow(try val.asColor())
        XCTAssertThrowsError(try SassConstants.true.asColor())

        XCTAssertEqual(colRgb, colRgb)
        let colHsl2 = try SassColor(hue: colRgb.hue,
                                    saturation: colRgb.saturation,
                                    lightness: colRgb.lightness,
                                    alpha: colRgb.alpha)
        XCTAssertEqual(colRgb, colHsl2)

        let dict = [colRgb: true]
        XCTAssertTrue(dict[colHsl2]!)
    }

    func testModificationRgb() throws {
        let col1 = try SassColor(red: 1, green: 2, blue: 3, alpha: 0.1)
        check(rgb: col1, 1, 2, 3, 0.1)
        let col2 = try col1.change(alpha: 0.9)
        check(rgb: col2, 1, 2, 3, 0.9)
        let col3 = try col2.change(red: 5)
        check(rgb: col3, 5, 2, 3, 0.9)
        let col4 = try col3.change(green: 12)
        check(rgb: col4, 5, 12, 3, 0.9)
        let col5 = try col4.change(blue: 15)
        check(rgb: col5, 5, 12, 15, 0.9)
        let col6 = try col5.change(red: 1, green: 2, blue: 3, alpha: 0.1)
        XCTAssertEqual(col1, col6)
    }

    func testModificationHsl() throws {
        let col1 = try SassColor(hue: 20, saturation: 30, lightness: 40, alpha: 0.7)
        check(hsl: col1, 20, 30, 40, 0.7)
        let col2 = try col1.change(alpha: 0.01)
        check(hsl: col2, 20, 30, 40, 0.01)
        let col3 = try col2.change(hue: 44)
        check(hsl: col3, 44, 30, 40, 0.01)
        let col4 = try col3.change(saturation: 32)
        check(hsl: col4, 44, 32, 40, 0.01)
        let col5 = try col4.change(lightness: 60)
        check(hsl: col5, 44, 32, 60, 0.01)
        let col6 = try col5.change(hue: 20, saturation: 30, lightness: 40, alpha: 0.7)
        XCTAssertEqual(col1, col6)
    }

    // odd corner where we generate the lazy color-rep then do an alpha-only change!
    func testCornerModification() throws {
        let col = try SassColor(red: 1, green: 2, blue: 3, alpha: 0.4)
        XCTAssertEqual(210, col.hue)
        let col2 = try col.change(alpha: 0.0)
        check(rgb: col2, 1, 2, 3, 0.0)
    }
}
