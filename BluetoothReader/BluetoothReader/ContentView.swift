//
//  ContentView.swift
//  BluetoothReader
//
//  Created by Beau Nouvelle on 14/2/2023.
//

import SwiftUI

struct ContentView: View {

    @StateObject var service = BluetoothService()
    @StateObject var audio = AudioPlayer()
    
    var body: some View {
        VStack {
            Text(service.peripheralStatus.rawValue)
                .font(.title)
            Text("\(service.magnetValue)")
                .font(.largeTitle)
                .fontWeight(.heavy)

            Button(action: {
                // Trigger audio playback action
                // For demonstration purposes, let's assume micData is available in BluetoothService
                audio.playPCMData(pcmData: service.micData)
            }) {
                Text("Play Audio")
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
