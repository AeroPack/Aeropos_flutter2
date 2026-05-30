import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? errorMessage;

  ProfileState({this.profile, this.isLoading = false, this.errorMessage});

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileController(this._repository) : super(ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> updateProfile(
    Map<String, dynamic> data, {
    File? imageFile,
    Uint8List? imageBytes,
    String? uploadType,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateProfile(
        data,
        imageFile: imageFile,
        imageBytes: imageBytes,
        uploadType: uploadType,
      );
      // Reload profile after update
      await loadProfile();

      // Mirror updated company fields into the local Tenants table so the
      // invoice hydration picks up the fresh values without a re-login.
      final profile = state.profile;
      final tenantId = ServiceLocator.instance.tenantService.tenantIdOrNull;
      if (profile != null && tenantId != null) {
        await ServiceLocator.instance.database.upsertTenantFromCompany(
          tenantId: tenantId,
          name: profile['businessName'] ?? profile['companyName'] ?? '',
          email: profile['email'] as String?,
          phone: profile['phone'] as String?,
          businessAddress: profile['businessAddress'] as String?,
          taxId: profile['taxId'] as String?,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      return ProfileController(ServiceLocator.instance.profileRepository);
    });
