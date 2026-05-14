import SwiftUI

struct AuthView: View {
    var onSuccess: (() -> Void)? = nil
    @State private var username = ""
    @State private var password = ""
    @State private var isRegisterMode = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @AppStorage("serverBaseURL") private var serverBaseURL = "https://poetry.xiuyuan.xin"
    @State private var showServerConfig = false

    var body: some View {
        NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("古诗词背诵")
                            .font(.title.bold())
                        Text(isRegisterMode ? "创建新账号" : "登录你的账号")
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            TextField("用户名", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            SecureField("密码", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegisterMode ? "注册" : "登录")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(formValid ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(!formValid || isLoading)

                        Button(isRegisterMode ? "已有账号？去登录" : "没有账号？去注册") {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                        .font(.subheadline)

                        Divider()

                        Button {
                            showServerConfig = true
                        } label: {
                            Label("服务器设置", systemImage: "gearshape")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                }
                .navigationTitle(isRegisterMode ? "注册" : "登录")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showServerConfig) {
                    ServerConfigView()
                }
            }
    }

    private var formValid: Bool {
        username.count >= 3 && username.count <= 64 && password.count >= 6
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isRegisterMode {
                _ = try await AuthService.register(username: username, password: password)
            } else {
                _ = try await AuthService.login(username: username, password: password)
            }
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            onSuccess?()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ServerConfigView: View {
    @AppStorage("serverBaseURL") private var serverBaseURL = "https://poetry.xiuyuan.xin"
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("服务器地址", text: $draft, prompt: Text("例如：192.168.1.100:3000"))
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("输入后端服务器的地址，包含端口号")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    serverBaseURL = draft
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(draft.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(draft.isEmpty)
            }
            .padding()
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { draft = serverBaseURL }
        }
    }
}

#Preview {
    AuthView()
}
