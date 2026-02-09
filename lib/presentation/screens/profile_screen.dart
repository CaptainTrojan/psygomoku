import 'package:flutter/material.dart';
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
        const SnackBar(
          content: Text('Profile saved!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProfile();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _resetProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E3E),
        title: const Text(
          'Reset Profile?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will reset your stats and match history. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
          const SnackBar(
            content: Text('Profile reset successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_player == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E27),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final matchHistory = widget.profileRepository.getMatchHistory();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E3E),
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetProfile,
            tooltip: 'Reset Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar and stats card
            Card(
              color: const Color(0xFF1A1E3E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Avatar
                    Container(
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox('Wins', _player!.wins, Colors.green),
                        _buildStatBox('Losses', _player!.losses, Colors.red),
                        _buildStatBox('Draws', _player!.draws, Colors.amber),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Win rate
                    Text(
                      'Win Rate: ${_player!.winRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nickname field
            const Text(
              'Nickname',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white),
              maxLength: 20,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1E3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter your nickname',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                counterStyle: const TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 24),

            // Avatar color picker
            const Text(
              'Avatar Color',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((colorHex) {
                final color = Color(
                  int.parse(colorHex.replaceFirst('#', ''), radix: 16) + 0xFF000000,
                );
                final isSelected = colorHex == _selectedAvatarColor;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarColor = colorHex;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Colors.white,
                              width: 3,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Match history
            const Text(
              'Match History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (matchHistory.isEmpty)
              const Card(
                color: Color(0xFF1A1E3E),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No matches played yet',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...matchHistory.map((match) {
                final didWin = match['didWin'] as bool? ?? false;
                final isDraw = match['isDraw'] as bool? ?? false;
                final opponent = match['opponentNickname'] as String? ?? 'Unknown';
                final result = match['result'] as String? ?? 'unknown';

                IconData icon;
                Color color;
                String text;

                if (isDraw) {
                  icon = Icons.handshake;
                  color = Colors.amber;
                  text = 'Draw vs $opponent';
                } else if (didWin) {
                  icon = Icons.emoji_events;
                  color = Colors.green;
                  text = 'Victory vs $opponent';
                } else {
                  icon = Icons.close;
                  color = Colors.red;
                  text = 'Loss vs $opponent';
                }

                return Card(
                  color: const Color(0xFF1A1E3E),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      result,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
