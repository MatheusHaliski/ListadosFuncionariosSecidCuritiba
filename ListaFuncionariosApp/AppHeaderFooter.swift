import SwiftUI

struct AppHeaderView: View {
    @Binding var mostrandoSobreSECID: Bool
    @AppStorage("app_theme_preference") private var appThemePreference: String = "system"
    
    var body: some View {
        HStack {
            Button {
                mostrandoSobreSECID.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .imageScale(.large)
            }
            Spacer()
            Text("Regionais SECID")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            Spacer()
            Picker(selection: $appThemePreference) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            } label: {
                Label("Theme", systemImage: "moon.circle")
            }
            .pickerStyle(MenuPickerStyle())
            .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}

struct AppFooterZoomView: View {
    @Binding var zoomScale: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Zoom: \(Int(zoomScale * 100))%")
                .font(.footnote)
                .foregroundColor(.primary)
            Slider(value: $zoomScale, in: 0.8...2.0, step: 0.05)
                .tint(.blue)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}

struct ScaffoldView<Content: View>: View {
    @State private var mostrandoSobreSECID = false
    @State private var zoomScale: CGFloat = 0.8
    
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(mostrandoSobreSECID: $mostrandoSobreSECID)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            AppFooterZoomView(zoomScale: $zoomScale)
        }
        .sheet(isPresented: $mostrandoSobreSECID) {
            SobreSECIDView()
        }
    }
}

struct AppHeaderView_Previews: PreviewProvider {
    @State static var mostrando = false
    
    static var previews: some View {
        AppHeaderView(mostrandoSobreSECID: $mostrando)
            .previewLayout(.sizeThatFits)
    }
}

struct AppFooterZoomView_Previews: PreviewProvider {
    @State static var zoom: CGFloat = 1.0
    
    static var previews: some View {
        AppFooterZoomView(zoomScale: $zoom)
            .previewLayout(.sizeThatFits)
    }
}

struct ScaffoldView_Previews: PreviewProvider {
    static var previews: some View {
        ScaffoldView {
            VStack(alignment: .leading) {
                Text("Placeholder content")
                    .padding()
                Spacer()
            }
        }
    }
}
