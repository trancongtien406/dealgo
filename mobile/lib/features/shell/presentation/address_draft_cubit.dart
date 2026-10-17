import 'package:flutter_bloc/flutter_bloc.dart';

class AddressDraftCubit extends Cubit<List<String>> {
  AddressDraftCubit() : super(const []);

  static const int limit = 2;

  bool addLabel(String raw) {
    final label = raw.trim();
    if (label.isEmpty || state.length >= limit || state.contains(label)) {
      return false;
    }
    emit([...state, label]);
    return true;
  }

  bool replaceLabel(int index, String raw) {
    final label = raw.trim();
    if (label.isEmpty || index < 0 || index >= state.length) {
      return false;
    }
    final duplicateAt = state.indexOf(label);
    if (duplicateAt != -1 && duplicateAt != index) {
      return false;
    }
    final next = [...state];
    next[index] = label;
    emit(next);
    return true;
  }

  void clear() {
    if (state.isEmpty) {
      return;
    }
    emit(const []);
  }
}
