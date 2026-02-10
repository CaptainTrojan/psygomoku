import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../infrastructure/persistence/profile_repository.dart';
import '../../domain/entities/player.dart';

/// Screen for viewing and editing player profile
class ProfileScreen extends StatefulWidget {
  final ProfileRepository profileRepository;

  const ProfileScreen({
    super.key,
    required this.profileRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nicknameController;
  late String _selectedAvatarColor;
  Player? _player;

  final List<String> _availableColors = [
    '#6B5B95', // Purple
    '#88B04B', // Green
    '#F7CAC9', // Pink
    '#92A8D1', // Blue
    '#955251', // Brown
    '#B565A7', // Magenta
    '#009B77', // Teal
    '#DD4124', // Red
    '#D65076', // Rose
    '#45B8AC', // Turquoise
    '#EFC050', // Yellow
    '#5B5EA6', // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _player = widget.profileRepository.getLocalPlayer();
    if (_player != null) {
      _nicknameController = TextEditingController(text: _player!.nickname);
      _selectedAvatarColor = _player!.avatarColor;
    } else {
      _nicknameController = TextEditingController(text: 'Player');
      _selectedAvatarColor = _availableColors[0];
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    
    // Validate nickname
    final validation = Player.validateNickname(nickname);
    if (validation != null) {
      _showError(validation);
      return;
    }

    await widget.profileRepository.updateProfile(
      nickname: nickname,
      avatarColor: _selectedAvatarColor,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile saved!'),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadProfile();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _resetProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title: Text(
          'Reset Profile?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will reset your stats and match history. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: AppButtonStyles.secondary(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: AppButtonStyles.danger(),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.profileRepository.resetProfile();
      _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile reset successfully'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_player == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: TechBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final matchHistory = widget.profileRepository.getMatchHistory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetProfile,
            tooltip: 'Reset Profile',
          ),
        ],
      ),
      body: TechBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;
            
            if (isDesktop) {
              return _buildDesktopLayout(matchHistory);
            } else {
              return _buildMobileLayout(matchHistory);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildMobileLayout(List matchHistory) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildProfileContent(matchHistory),
        ),
      ),
    );
  }
  
  Widget _buildDesktopLayout(List matchHistory) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Avatar and settings
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAvatarCard(),
                    const SizedBox(height: 16),
                    _buildNicknameCard(),
                    const SizedBox(height: 16),
                    _buildColorPickerCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right column: Stats and match history
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildMatchHistoryCard(matchHistory),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  List<Widget> _buildProfileContent(List matchHistory) {
    return [
      // Avatar and stats card
      _buildAvatarAndStatsCard(),
      const SizedBox(height: 16),
      
      // Nickname field
      _buildNicknameCard(),
      const SizedBox(height: 16),
      
      // Color picker
      _buildColorPickerCard(),
      const SizedBox(height: 24),
      
      // Save button
      _buildSaveButton(),
      const SizedBox(height: 24),
      
      // Match history
      _buildMatchHistoryCard(matchHistory),
    ];
  }
  
  Widget _buildAvatarAndStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 24),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatarCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: _buildAvatar()),
      ),
    );
  }
  
  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: TextStyle(
                fontSize: responsiveTextSize(context, 20),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Color(
          int.parse(_selectedAvatarColor.replaceFirst('#', ''), radix: 16) +
              0xFF000000,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(
              int.parse(_selectedAvatarColor.replaceFirst('#', ''), radix: 16) +
                  0xFF000000,
            ).withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _player!.initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: responsiveTextSize(context, 48),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox('Wins', _player!.wins, AppColors.primary),
        _buildStatBox('Losses', _player!.losses, AppColors.error),
        _buildStatBox('Draws', _player!.draws, AppColors.warning),
      ],
    );
  }
  
  Widget _buildNicknameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            hintText: 'Enter your nickname',
          ),
          maxLength: 20,
        ),
      ),
    );
  }
  
  Widget _buildColorPickerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avatar Color',
              style: TextStyle(
                fontSize: responsiveTextSize(context, 16),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedAvatarColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarColor = color;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(color.replaceFirst('#', ''), radix: 16) +
                            0xFF000000,
                      ),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: AppButtonStyles.primary(),
      child: const Text('Save Profile'),
    );
  }
  
  Widget _buildMatchHistoryCard(List matchHistory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match History',
              style: TextStyle(
                fontSize: responsiveTextSize(context, 20),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            matchHistory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No matches played yet',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: responsiveTextSize(context, 14),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: matchHistory.length > 10 ? 10 : matchHistory.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final match = matchHistory[index];
                      return ListTile(
                        leading: Icon(
                          _getMatchIcon(match['result']),
                          color: _getMatchColor(match['result']),
                        ),
                        title: Text(
                          match['result'].toString().split('.').last.toUpperCase(),
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'vs ${match['opponent']}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Text(
                          _formatDate(match['date']),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: responsiveTextSize(context, 12),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
  
  IconData _getMatchIcon(dynamic result) {
    final resultStr = result.toString().split('.').last;
    switch (resultStr) {
      case 'win':
        return Icons.emoji_events;
      case 'loss':
        return Icons.cancel;
      case 'draw':
        return Icons.handshake;
      default:
        return Icons.help;
    }
  }
  
  Color _getMatchColor(dynamic result) {
    final resultStr = result.toString().split('.').last;
    switch (resultStr) {
      case 'win':
        return AppColors.primary;
      case 'loss':
        return AppColors.error;
      case 'draw':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildStatBox(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: responsiveTextSize(context, 32),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: responsiveTextSize(context, 14),
          ),
        ),
      ],
    );
  }
}
