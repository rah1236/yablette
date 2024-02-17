//
//  BluetoothService.swift
//  BluetoothReader
//
//  Created by Beau Nouvelle on 14/2/2023.
//

import Foundation
import CoreBluetooth
import AVFoundation


enum ConnectionStatus: String {
    case connected
    case disconnected
    case scanning
    case connecting
    case error
}

let hallSensorService: CBUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
let hallSensorCharacteristic: CBUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")




class BluetoothService: NSObject, ObservableObject {

    private var centralManager: CBCentralManager!

    private var audioPlayer: AVAudioPlayer?
    
    var micData: [Int32] = Array(repeating: 0, count: 44100*5)
    var micDataIndex: Int = 0
    var micDataReady = false
    
    var hallSensorPeripheral: CBPeripheral?
    @Published var peripheralStatus: ConnectionStatus = .disconnected
    @Published var magnetValue: Int32 = 0

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func scanForPeripherals() {
        peripheralStatus = .scanning
        centralManager.scanForPeripherals(withServices: nil)
    }
    
    func playAudioFromPCMData(pcmData: [Int32]) {
            let audioPlayer = AudioPlayer()
            audioPlayer.playPCMData(pcmData: pcmData)
    }

}

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("CB Powered On")
            scanForPeripherals()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered \(peripheral.name ?? "no name")")

        if peripheral.name == "Magnet Sensor" {
            print("Discovered \(peripheral.name ?? "no name")")
            hallSensorPeripheral = peripheral
            centralManager.connect(hallSensorPeripheral!)
            peripheralStatus = .connecting
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheralStatus = .connected

        peripheral.delegate = self
        peripheral.discoverServices([hallSensorService])
        centralManager.stopScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripheralStatus = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripheralStatus = .error
        print(error?.localizedDescription ?? "no error")
    }

}

extension BluetoothService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == hallSensorService {
                print("found service for \(hallSensorService)")
                peripheral.discoverCharacteristics([hallSensorCharacteristic], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            peripheral.setNotifyValue(true, for: characteristic)
            print("found characteristic, waiting on values.")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == hallSensorCharacteristic {
            guard let data = characteristic.value else {
                print("No data received for \(characteristic.uuid.uuidString)")
                return
            }
            
            let sensorData: Int32 = data.withUnsafeBytes{ $0.pointee }
            print(sensorData)
            magnetValue = sensorData
            if micDataIndex < 44100 * 5 - 1{ //5 Seconds of audio
                micData[micDataIndex] = sensorData
                micDataIndex += 1
            }
            else{
                micDataReady = true
                micDataIndex = 0
            }
            if micDataReady{
                print(micData)
            }
        }
    }

}

// Add the AudioPlayer class for audio playback
class AudioPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    func playPCMData(pcmData: [Int32]) {
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt32,
                                         sampleRate: 44100,
                                         channels: 1,
                                         interleaved: false)

        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: UInt32(pcmData.count))
        pcmBuffer!.frameLength = UInt32(pcmData.count)
        let buffer = pcmBuffer!.audioBufferList.pointee.mBuffers
        buffer.mData?.copyMemory(from: pcmData, byteCount: pcmData.count * MemoryLayout<Int32>.size)

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)

        playerNode.scheduleBuffer(pcmBuffer!, completionHandler: nil)

        try? engine.start()

        playerNode.play()
    }
}
