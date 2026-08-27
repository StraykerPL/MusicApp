import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:strayker_music/Shared/input_security.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _playedSongsMaxAmountInputController =
      TextEditingController();
  final TextEditingController _newPlaylistNameController =
      TextEditingController();

  SettingsViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<SettingsViewModel>();
    if (_viewModel != viewModel) {
      _viewModel?.removeListener(_syncPlayedSongsInput);
      _viewModel = viewModel;
      _viewModel!.addListener(_syncPlayedSongsInput);
      _syncPlayedSongsInput();
    }
  }

  void _syncPlayedSongsInput() {
    final text = _viewModel!.playedSongsMaxAmountText;
    if (_playedSongsMaxAmountInputController.text == text) {
      return;
    }
    _playedSongsMaxAmountInputController.value =
        _playedSongsMaxAmountInputController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _createPlaylist() async {
    final result = await _viewModel!.createPlaylist(
      _newPlaylistNameController.text,
    );
    if (!mounted) {
      return;
    }
    if (result is SettingsCommandSuccess) {
      _newPlaylistNameController.clear();
    } else if (result is SettingsCommandFailure) {
      _showErrorDialog(result.message);
    }
  }

  Future<void> _deletePlaylist() async {
    final result = await _viewModel!.deleteSelectedPlaylist();
    if (mounted && result is SettingsCommandFailure) {
      _showErrorDialog(result.message);
    }
  }

  Future<void> _save() async {
    _viewModel!.setPlayedSongsMaxAmountFromText(
      _playedSongsMaxAmountInputController.text,
    );
    final result = await _viewModel!.save();
    if (mounted && result is SettingsCommandFailure) {
      _showErrorDialog(result.message);
    }
  }

  Future<void> _restoreDefaults() async {
    final result = await _viewModel!.restoreDefaults();
    if (mounted && result is SettingsCommandFailure) {
      _showErrorDialog(result.message);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAudioFolderPicker(SettingsViewModel viewModel) async {
    final labels = viewModel.availableAudioFolderDisplayPaths;
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder Select'),
        content: SizedBox(
          width: double.maxFinite,
          child: labels.isEmpty
              ? const Text('No indexed audio folders found.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: labels.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(labels[index]),
                    onTap: () => Navigator.of(context).pop(index),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedIndex == null || !mounted) return;

    final result = viewModel.addAvailableAudioFolder(selectedIndex);

    if (result is SettingsCommandFailure) {
      _showErrorDialog(result.message);
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_syncPlayedSongsInput);
    _playedSongsMaxAmountInputController.dispose();
    _newPlaylistNameController.dispose();
    super.dispose();
  }

  Widget _createPathsListWidget(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: viewModel.storageLocationDisplayPaths.length,
      itemBuilder: (context, index) {
        final storageLocation = viewModel.storageLocationDisplayPaths[index];
        return ListTile(
          title: Text(
            storageLocation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: viewModel.selectedStorageLocationIndex == index
              ? getDefaultIconWidget(context, Icons.check)
              : null,
          onTap: () => viewModel.selectStorageLocation(index),
        );
      },
    );
  }

  Widget _createPlaylistsListWidget(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: viewModel.playlists.length,
      itemBuilder: (context, index) {
        final playlist = viewModel.playlists[index];
        final playlistName = playlist.name;
        final isAllFiles = playlistName == Constants.allFilesListName;

        return ListTile(
          title: Text(
            playlistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: viewModel.selectedPlaylistName == playlistName
              ? getDefaultIconWidget(context, Icons.check)
              : null,
          onTap:
              isAllFiles ? null : () => viewModel.selectPlaylist(playlistName),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Amount of repetitive songs prevention queue\n(zero means this feature is disabled):',
                textAlign: TextAlign.center,
              ),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: _playedSongsMaxAmountInputController,
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    const SecureTextInputFormatter(),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: viewModel.setPlayedSongsMaxAmountFromText,
                  keyboardType: TextInputType.number,
                ),
              ),
              const Text('Storage paths to look for sound files:'),
              SizedBox(
                width: double.infinity,
                height: 300,
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _showAudioFolderPicker(viewModel),
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.color,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: viewModel.removeSelectedStoragePath,
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      child: _createPathsListWidget(context, viewModel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Playlist Management:'),
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _newPlaylistNameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter playlist name',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              const SecureTextInputFormatter(),
                              LengthLimitingTextInputFormatter(
                                InputSecurity.maxTextLength,
                              ),
                            ],
                            onSubmitted: (_) => _createPlaylist(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _createPlaylist,
                          child: Text(
                            'Create',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.color,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: viewModel.selectedPlaylistName != null &&
                                  viewModel.selectedPlaylistName !=
                                      Constants.allFilesListName
                              ? _deletePlaylist
                              : null,
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _createPlaylistsListWidget(context, viewModel),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: viewModel.isPersistenceInProgress ? null : _save,
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.displayLarge?.color,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: viewModel.isPersistenceInProgress
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.displayLarge?.color,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: viewModel.isPersistenceInProgress
                        ? null
                        : _restoreDefaults,
                    child: Text(
                      'Load Default',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.displayLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
