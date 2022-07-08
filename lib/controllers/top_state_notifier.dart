import 'package:clipit/models/directable.dart';
import 'package:clipit/models/tree_node.dart';
import 'package:state_notifier/state_notifier.dart';

import '../models/history.dart';
import '../models/pin.dart';
import '../models/selectable.dart';
import '../models/side_type.dart';
import '../models/trash.dart';
import '../states/top_state.dart';

class TopStateNotifier extends StateNotifier<TopState> {
  TopStateNotifier()
      : super(TopState(
            histories:
                HistoryList(currentIndex: 0, listTitle: "history", value: []),
            pins: PinList(currentIndex: 0, listTitle: "pin", value: []),
            trashes: TrashList(currentIndex: 0, listTitle: "trash", value: []),
            listCurrentNode: TreeNode(
                name: "root", isDir: true, isSelected: false, children: []),
            searchListCurrentNode: TreeNode(
                name: "root",
                isDir: true,
                isSelected: false,
                children: [
                  TreeNode(
                      name: "history",
                      isDir: true,
                      isSelected: false,
                      children: []),
                  TreeNode(
                      name: "pin", isDir: true, isSelected: false, children: [])
                ]),
            type: ScreenType.CLIP,
            showSearchBar: false,
            showSearchResult: false));

  void increment() {
    state = state.incrementCurrentItems();
  }

  void decrement() {
    state = state.decrementCurrentItems();
  }

  void selectFirstItem() {
    state.listCurrentNode.isSelected = false;
    state.currentDirNodes.first.isSelected = true;
    state = state.copyWith(listCurrentNode: state.currentDirNodes.first);
  }

  void selectLastItem() {
    state.listCurrentNode.isSelected = false;
    state.currentDirNodes.last.isSelected = true;
    state = state.copyWith(listCurrentNode: state.currentDirNodes.last);
  }

  void moveToTargetNode(TreeNode target) {
    state.listCurrentNode.isSelected = false;
    target.isSelected = true;
    state = state.copyWith(
        listCurrentNode: target,
        searchResults: [],
        showSearchResult: false,
        showSearchBar: false);
    state;
  }

  void selectTargetItem(int targetIndex) {
    state = state.switchCurrentItems(targetIndex);
  }

  void retlieveTree(HistoryList histories, PinList pins, TrashList trashes) {
    state = state
        .copyWith(histories: histories, pins: pins, trashes: trashes)
        .buildTree(histories, pins, trashes)
        .selectFirstNode();
  }

  void selectFirstNode() {
    state = state.selectFirstNode();
  }

  void insertHistoryToHead(History history) {
    state = state.copyWith(histories: state.histories.insertToFirst(history));
  }

  void changeType(ScreenType type) {
    state = state.copyWith(type: type);
  }

  void deleteHistory(History history) {
    state =
        state.copyWith(histories: state.histories.deleteTargetHistory(history));
  }

  void deleteCurrentHistory() {
    state = state.copyWith(histories: state.histories.deleteCurrentHistory());
  }

  void insertPinToHead(Pin pin) {
    state = state.copyWith(pins: state.pins.insertToFirst(pin));
  }

  void archiveHistory(History history) {}

  void clearSearchResult() {
    state = state.copyWith(
        searchResults: [], showSearchResult: false, showSearchBar: false);
  }

  void searchSelectables(String text) {
    state.getSearchResult(text).then((value) {
      state = value.copyWith(showSearchResult: true);
    });
  }

  void updateSearchBarVisibility(bool isVisible) {
    state = state.copyWith(showSearchBar: isVisible);
  }

  void moveToNext() {
    state = state.moveToNext();
  }

  void moveToPrev() {
    state = state.moveToPrev();
  }
}
