import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_view_settings.dart';

class FileSettings {
  final FileViewMode viewMode;
  final FileLayout layout;
  final FileSortOption sortOption;
  final bool isAscending;

  FileSettings({
    this.viewMode = FileViewMode.folders,
    this.layout = FileLayout.list,
    this.sortOption = FileSortOption.date,
    this.isAscending = false,
  });

  FileSettings copyWith({
    FileViewMode? viewMode,
    FileLayout? layout,
    FileSortOption? sortOption,
    bool? isAscending,
  }) {
    return FileSettings(
      viewMode: viewMode ?? this.viewMode,
      layout: layout ?? this.layout,
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
    );
  }
}

final fileSettingsProvider =
    StateNotifierProvider<FileSettingsNotifier, FileSettings>((ref) {
      return FileSettingsNotifier();
    });

class FileSettingsNotifier extends StateNotifier<FileSettings> {
  FileSettingsNotifier() : super(FileSettings());

  void setViewMode(FileViewMode mode) => state = state.copyWith(viewMode: mode);
  void setLayout(FileLayout layout) => state = state.copyWith(layout: layout);
  void setSortOption(FileSortOption option) =>
      state = state.copyWith(sortOption: option);
  void setIsAscending(bool isAscending) =>
      state = state.copyWith(isAscending: isAscending);

  void updateAll({
    required FileViewMode viewMode,
    required FileLayout layout,
    required FileSortOption sortOption,
    required bool isAscending,
  }) {
    state = state.copyWith(
      viewMode: viewMode,
      layout: layout,
      sortOption: sortOption,
      isAscending: isAscending,
    );
  }
}
