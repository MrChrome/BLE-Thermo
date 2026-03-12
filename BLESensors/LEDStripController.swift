import CoreBluetooth
import Foundation

/// Manages the BLE connection to a single LED strip and sends protocol commands.
class LEDStripController {
    private let peripheral: CBPeripheral
    private let writeChar: CBCharacteristic
    private let delegate: ObjCBLEDelegate

    // Current state (kept in sync so we can resend after reconnect)
    private var isOn: Bool = true
    private var brightness: Int = 100   // 0–100
    private var hue: Float = 0          // 0–360
    private var saturation: Float = 0   // 0–100

    init(peripheral: CBPeripheral, writeChar: CBCharacteristic, delegate: ObjCBLEDelegate) {
        self.peripheral = peripheral
        self.writeChar  = writeChar
        self.delegate   = delegate
    }

    // MARK: - HomeKit-facing setters

    func setPower(_ on: Bool) {
        isOn = on
        let byte: UInt8 = on ? 0x01 : 0x00
        send([0x7e, 0x00, 0x04, byte, 0x00, 0x00, 0x00, 0x00, 0xef])
    }

    func setBrightness(_ percent: Int) {
        brightness = percent
        sendCurrentColor()
    }

    func setColor(hue: Float, saturation: Float) {
        self.hue        = hue
        self.saturation = saturation
        sendCurrentColor()
    }

    func setColorRGB(r: UInt8, g: UInt8, b: UInt8) {
        let scale = Float(brightness) / 100.0
        let sr = UInt8(Float(r) * scale)
        let sg = UInt8(Float(g) * scale)
        let sb = UInt8(Float(b) * scale)
        send([0x7e, 0x00, 0x05, 0x03, sr, sg, sb, 0x10, 0xef])
    }

    private func sendCurrentColor() {
        let (r, g, b) = hsbToRGB(hue: hue, saturation: saturation, brightness: Float(brightness))
        send([0x7e, 0x00, 0x05, 0x03, r, g, b, 0x10, 0xef])
    }

    // MARK: - Private

    private func send(_ bytes: [UInt8]) {
        let data = Data(bytes)
        peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
    }

    /// Converts HSB (HomeKit ranges: H 0–360, S 0–100, B always 100) to RGB bytes.
    private func hsbToRGB(hue: Float, saturation: Float, brightness: Float) -> (UInt8, UInt8, UInt8) {
        let h = hue / 360.0
        let s = saturation / 100.0
        let v = brightness / 100.0

        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        let (r, g, b): (Float, Float, Float)
        switch i % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default:(r, g, b) = (v, p, q)
        }

        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}
