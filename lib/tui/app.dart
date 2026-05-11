import 'package:dart_tui/dart_tui.dart';

import 'model.dart';
import 'update.dart';
import 'view.dart';

/// Wraps [NemotronState] in the dart_tui Elm [Model] interface.
final class NemotronAppModel extends Model {
  NemotronAppModel(this.state);
  final NemotronState state;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    final (newState, cmd) = nemotronUpdate(state, msg);
    return (NemotronAppModel(newState), cmd);
  }

  @override
  View view() => nemotronView(state);
}
