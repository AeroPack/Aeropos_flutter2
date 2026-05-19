import '../../../../core/models/user.dart';
import '../../../../core/models/company.dart';

abstract class AuthRepository {
  /// Login with email/password. Returns companies list if multi-company selection is required.
  Future<Map<String, dynamic>> login(String email, String password, {int? companyId});
  Future<void> signup(Map<String, dynamic> data);
  Future<Map<String, dynamic>> googleLogin({String? idToken, String? accessToken, int? companyId});
  Future<void> logout();
  Future<bool> checkAuthStatus();
  Future<User?> getCurrentUser();
  Future<void> verifyEmail(String token);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String newPassword);
  Future<void> resendVerificationEmail(String email);
  Future<List<Company>> getMyCompanies();
  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> data);
  Future<Map<String, dynamic>> switchCompany(int companyId);
}
