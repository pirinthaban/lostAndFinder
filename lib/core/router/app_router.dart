import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/onboarding_screen.dart';
import '../../features/authentication/presentation/screens/phone_verification_screen.dart';
import '../../features/authentication/presentation/screens/otp_screen.dart';
import '../../features/authentication/presentation/screens/profile_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/items/presentation/screens/post_item_screen.dart';
import '../../features/items/presentation/screens/item_detail_screen.dart';
import '../../features/claims/presentation/screens/claim_flow_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/police/presentation/screens/police_dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Authentication Routes
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/phone-verification',
        name: 'phoneVerification',
        builder: (context, state) => const PhoneVerificationScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) {
          final verificationId = state.extra as String;
          return OTPScreen(verificationId: verificationId);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profileSetup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Main App Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Item Routes
      GoRoute(
        path: '/post-item',
        name: 'postItem',
        builder: (context, state) {
          final itemType = state.extra as String?;
          return PostItemScreen(itemType: itemType);
        },
      ),
      GoRoute(
        path: '/item/:itemId',
        name: 'itemDetail',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return ItemDetailScreen(itemId: itemId);
        },
      ),

      // Claim Routes
      GoRoute(
        path: '/claim/:itemId',
        name: 'claimFlow',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return ClaimFlowScreen(itemId: itemId);
        },
      ),

      // Chat Routes
      GoRoute(
        path: '/chats',
        name: 'chatList',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatScreen(chatId: chatId);
        },
      ),

      // Profile Routes
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // Police Routes
      GoRoute(
        path: '/police-dashboard',
        name: 'policeDashboard',
        builder: (context, state) => const PoliceDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => const SplashScreen(),
  );
});
