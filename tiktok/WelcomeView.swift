import SwiftUI
import FirebaseAuth

// MARK: - WelcomeView

struct WelcomeView: View {
    @Binding var isLoggedIn: Bool
    @State private var showLogin = false
    @State private var showSignup = false
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                TeacherLogo()
                    .frame(width: 70, height: 70) // Adjust the frame as needed
                
                
                Text("TeacherTok")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
                
                Text("A social platform for educators to share engaging content")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: { showLogin = true }) {
                        Text("Log in with email")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: { showSignup = true }) {
                        Text("Sign up")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: {
                        // Action for Apple login (to be integrated)
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)
                
                Text("By continuing, you agree to our Terms of Service and acknowledge that you have read our Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isLoggedIn: $isLoggedIn)
        }
        .sheet(isPresented: $showSignup) {
            SignupView(isLoggedIn: $isLoggedIn)
        }
    }
}

// MARK: - LoginView

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Consistent dark background
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "Email", text: $email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .onAppear{
                            focusedField = .email
                        }
                    
                    CustomSecureField(placeholder: "Password", text: $password)
                        .focused($focusedField, equals: .password)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        } else {
                            Text("Log in")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    
                    // Optional: "Forgot Password?" link
                    Button(action: {
                        // Implement "Forgot Password?" functionality if needed.
                    }) {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .padding(.top, 10)
                }
                .padding()
                .padding(.horizontal, 30)
            }
            .navigationTitle("Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
         .onAppear{
             isLoggedIn = true
         }
    }
    
    // MARK: - Firebase Login Function
    
    func login() {
        errorMessage = nil
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            // Successfully logged in
            isLoggedIn = true
            dismiss()
        }
    }
}

// MARK: - SignupView

struct SignupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark gradient background for consistency
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "Email", text: $email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    
                    CustomSecureField(placeholder: "Password", text: $password)
                        .focused($focusedField, equals: .password)
                    
                    CustomSecureField(placeholder: "Confirm Password", text: $confirmPassword)
                        .focused($focusedField, equals: .confirmPassword)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: signup) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        } else {
                            Text("Sign up")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                }
                .padding()
                .padding(.horizontal, 30)
            }
            .navigationTitle("Sign up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Firebase Signup Function
    
    func signup() {
        errorMessage = nil
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        isLoading = true
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
        print("Error creating user: \(error.localizedDescription)")
                    print("Error details: \(error)")
                    errorMessage = error.localizedDescription
                    return
            }
            // Successfully signed up and logged in
            isLoggedIn = true
            dismiss()
        }
    }
}

// MARK: - Custom TextField Styles

// MARK: - Updated Custom TextField Styles

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 16)
            }
            TextField("", text: $text)
                .padding()
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .autocapitalization(.none)
        }
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 16)
            }
            SecureField("", text: $text)
                .padding()
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(isLoggedIn: .constant(false))
    }
}
