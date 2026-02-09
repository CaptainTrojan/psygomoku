import 'package:hive/hive.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/stone.dart';

/// Hive adapter for Player entity
class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 0; // Unique type ID for Hive

  @override
  Player read(BinaryReader reader) {
    return Player(
      id: reader.readString(),
      nickname: reader.readString(),
      avatarColor: reader.readString(),
      wins: reader.readInt(),
      losses: reader.readInt(),
      draws: reader.readInt(),
      isHost: reader.readBool(),
      stoneColor: reader.readBool() 
          ? StoneColor.values[reader.readInt()]
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.nickname);
    writer.writeString(obj.avatarColor);
    writer.writeInt(obj.wins);
    writer.writeInt(obj.losses);
    writer.writeInt(obj.draws);
    writer.writeBool(obj.isHost);
    
    // Nullable stoneColor
    if (obj.stoneColor != null) {
      writer.writeBool(true);
      writer.writeInt(obj.stoneColor!.index);
    } else {
      writer.writeBool(false);
    }
  }
}
