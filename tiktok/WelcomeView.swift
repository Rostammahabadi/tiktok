import SwiftUI
import FirebaseAuth

// MARK: - WelcomeView

struct WelcomeView: View {
    @Binding var isLoggedIn: Bool
    @State private var showLogin = false
    @State private var showSignup = false
    @State private var isAnimating = false
    
    let gradientColors: [Color] = [
        Color(red: 0.98, green: 0.4, blue: 0.4),   // Playful red
        Color(red: 0.98, green: 0.8, blue: 0.3),   // Warm yellow
        Color(red: 0.4, green: 0.8, blue: 0.98)    // Sky blue
    ]
    
    var body: some View {
        ZStack {
            // Playful gradient background
            LinearGradient(gradient: Gradient(colors: gradientColors),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .position(x: geometry.size.width * 0.8,
                                    y: geometry.size.height * 0.2)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                            .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                                     value: isAnimating)
                    }
                )
            
            VStack(spacing: 25) {
                Spacer()
                
                // Animated logo with improved visibility
                TeacherLogo()
                    .frame(width: 90, height: 90)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                             value: isAnimating)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Text("TeacherTok")
                    .font(.custom("Avenir-Heavy", size: 48))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                
                // Fun tagline with improved contrast
                Text("Where Teaching Meets Fun! 🎓✨")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                // Achievement preview with improved contrast
                HStack(spacing: 20) {
                    AchievementBadge(icon: "star.fill", text: "Create")
                    AchievementBadge(icon: "person.2.fill", text: "Connect")
                    AchievementBadge(icon: "lightbulb.fill", text: "Inspire")
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Login buttons with improved contrast
                VStack(spacing: 16) {
                    Button(action: { showLogin = true }) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .font(.title3)
                            Text("Log in to Your Classroom")
                                .font(.headline)
                        }
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: { showSignup = true }) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                                .font(.title3)
                            Text("Join the Community")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: {
                        // Action for Apple login
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
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 30)
                
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isLoggedIn: $isLoggedIn)
        }
        .sheet(isPresented: $showSignup) {
            SignupView(isLoggedIn: $isLoggedIn)
        }
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.2))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
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
    @State private var isAnimating: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    let gradientColors: [Color] = [
        Color(red: 0.98, green: 0.4, blue: 0.4),   // Playful red
        Color(red: 0.98, green: 0.8, blue: 0.3),   // Warm yellow
        Color(red: 0.4, green: 0.8, blue: 0.98)    // Sky blue
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Matching gradient background
                LinearGradient(gradient: Gradient(colors: gradientColors),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .overlay(
                        GeometryReader { geometry in
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 200, height: 200)
                                .position(x: geometry.size.width * 0.8,
                                        y: geometry.size.height * 0.2)
                                .scaleEffect(isAnimating ? 1.2 : 0.8)
                                .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                                         value: isAnimating)
                        }
                    )
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Animated welcome message
                        VStack(spacing: 10) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                         value: isAnimating)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Text("Welcome Back!")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        .padding(.top, 60) // Add more top padding to prevent content from being too high
                        
                        // Login form with improved styling
                        VStack(spacing: 20) {
                            // Email field with icon
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                    .frame(width: 24)
                                CustomTextField(
                                    placeholder: "Email",
                                    text: $email,
                                    contentType: .username
                                )
                                .focused($focusedField, equals: .email)
                                .keyboardType(.emailAddress)
                            }
                            
                            // Password field with icon
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                                    .frame(width: 24)
                                CustomTextField(
                                    placeholder: "Password",
                                    text: $password,
                                    contentType: .password,
                                    isSecure: true
                                )
                                .focused($focusedField, equals: .password)
                            }
                            
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            
                            // Login button with animation
                            Button(action: login) {
                                ZStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.2, blue: 0.3)))
                                    } else {
                                        HStack {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.title3)
                                            Text("Let's Go!")
                                                .font(.headline)
                                        }
                                    }
                                }
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .scaleEffect(isLoading ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isLoading)
                            
                            // Forgot Password button with improved styling
                            Button(action: {
                                // Implement "Forgot Password?" functionality
                            }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50) // Add minimum spacing at the bottom
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
        .onAppear {
            isAnimating = true
            focusedField = .email
//            isLoggedIn = true
        }
    }
    
    func login() {
        errorMessage = nil
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
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
    @State private var showUsernameSelection: Bool = false
    @State private var authResult: AuthDataResult?
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    private let gradientColors: [Color] = [
        Color(red: 0.98, green: 0.4, blue: 0.4),   // Playful red
        Color(red: 0.98, green: 0.8, blue: 0.3),   // Warm yellow
        Color(red: 0.4, green: 0.8, blue: 0.98)    // Sky blue
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated gradient background
                LinearGradient(gradient: Gradient(colors: gradientColors),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .blur(radius: 10)
                            .offset(x: 150, y: -200)
                    )
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Welcome animation
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .padding(.top, 40)
                        
                        Text("Join TeacherTok")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        
                        // Input fields with improved styling
                        VStack(spacing: 20) {
                            CustomTextField(
                                placeholder: "Email",
                                text: $email,
                                contentType: .username
                            )
                            .focused($focusedField, equals: .email)
                            .keyboardType(.emailAddress)
                            
                            CustomTextField(
                                placeholder: "Password",
                                text: $password,
                                contentType: .password,
                                isSecure: true
                            )
                            .focused($focusedField, equals: .password)
                            
                            CustomTextField(
                                placeholder: "Confirm Password",
                                text: $confirmPassword,
                                contentType: .password,
                                isSecure: true
                            )
                            .focused($focusedField, equals: .confirmPassword)
                        }
                        .padding(.horizontal, 20)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(10)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Sign up button with loading state
                        Button(action: signup) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryColor))
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.title3)
                                        Text("Continue")
                                            .font(.headline)
                                    }
                                }
                            }
                            .foregroundColor(Theme.primaryColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.white)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showUsernameSelection) {
            if let authResult = authResult {
                UsernameSelectionView(isLoggedIn: $isLoggedIn, authResult: authResult)
            }
        }
        .onAppear {
            focusedField = .email
        }
    }
    
    func signup() {
        print("📝 Starting signup process...")
        errorMessage = nil
        isLoading = true
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            isLoading = false
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }
            
            guard let result = result else {
                isLoading = false
                errorMessage = "Failed to get authentication result"
                return
            }
            
            // Store the auth result and show username selection
            authResult = result
            isLoading = false
            showUsernameSelection = true
        }
    }
}

// MARK: - Custom TextField Styles

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var contentType: UITextContentType?
    var isSecure: Bool = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 16)
            }
            
            if isSecure {
                SecureField("", text: $text)
                    .textContentType(contentType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            } else {
                TextField("", text: $text)
                    .textContentType(contentType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .foregroundColor(.white)
                    .frame(height: 50)
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
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(isLoggedIn: .constant(false))
    }
}
