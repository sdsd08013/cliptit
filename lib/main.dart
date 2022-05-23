import 'package:clipit/models/clip.dart';
import 'package:clipit/models/side_type.dart';
import 'package:clipit/repositories/clip_repository.dart';
import 'package:clipit/color.dart';
import 'package:clipit/icon_text.dart';
import 'package:clipit/repositories/note_repository.dart';
import 'package:clipit/views/contents_header.dart';
import 'package:clipit/views/contents_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:async';
import 'dart:core';

import 'models/note.dart';
import 'models/trash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clipit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Clipit'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const channelName = 'clipboard/html';
  final methodChannel = const MethodChannel(channelName);
  final clipRepository = ClipRepository();
  final noteRepository = NoteRepository();
  final listViewController = ScrollController();
  ClipList clips = ClipList(value: []);
  NoteList notes = NoteList(value: []);
  TrashList trashes = TrashList(value: []);
  double offset = 0;
  double dragStartPos = 0;
  ScreenType type = ScreenType.CLIP;
  String lastText = "";

  @override
  void initState() {
    super.initState();

    retlieveClips();
    retlieveNotes();
    //clipRepository.dropTable();

    Future.delayed(Duration.zero, () {
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        getClipboardHtml();
      });
    });
  }

  getClipboardHtml() async {
    try {
      final result = await methodChannel.invokeMethod('getClipboardContent');
      if (result != lastText) {
        if (result != null) {
          createOrUpdateItem(result);
          lastText = result;
        }
      }
    } on PlatformException catch (e) {
      print("error in getting clipboard image");
      print(e);
    }
  }

  Future<void> retlieveClips() async {
    final retlievedClips = await clipRepository.getClips();
    setState(() {
      clips = retlievedClips ?? ClipList(value: []);
    });
  }

  Future<void> retlieveNotes() async {
    final retlievedNotes = await noteRepository.getNotes();
    setState(() {
      notes = retlievedNotes ?? NoteList(value: []);
    });
  }

  void createOrUpdateItem(String result) async {
    if (notes.isExist(result)) return;
    if (clips.isExist(result)) {
      if (clips.shouldUpdate(result)) {
        setState(() {
          clips.updateTargetClip(result);
          clips;
        });
        await clipRepository.updateClip(clips.currentItem);
      }
    } else {
      final id = await clipRepository.saveClip(result);
      setState(() {
        clips.insertToFirst(Clip(
            id: id,
            text: result,
            isSelected: true,
            count: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()));
        clips;
      });
    }
  }

  void handleSideBarTap(ScreenType newType) {
    setState(() {
      type = newType;
    });
  }

  void handleArchiveItemTap() async {
    final target = clips.currentItem;
    clipRepository.deleteClip(target.id);
    clips.deleteTargetClip(target);
    final noteId = await noteRepository.saveNote(target.text);
    notes.insertToFirst(Note(
        id: noteId,
        text: target.text,
        isSelected: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()));
    setState(() {
      clips;
      notes;
    });
  }

  void handleListViewItemTap(int index) {
    if (type == ScreenType.CLIP) {
      clips.switchItem(index);
      setState(() {
        clips;
      });
    } else if (type == ScreenType.PINNED) {
      notes.switchItem(index);
      setState(() {
        notes;
      });
    }
  }

  void handleListDown() {
    print("--------->");
    print(notes.currentItem.mdText);
    if (type == ScreenType.CLIP) {
      setState(() {
        clips.incrementIndex();
        clips;
      });
    } else if (type == ScreenType.PINNED) {
      setState(() {
        notes.incrementIndex();
        notes;
      });
    }
  }

  void handleListUp() {
    if (type == ScreenType.CLIP) {
      setState(() {
        clips.decrementIndex();
        clips;
      });
    } else if (type == ScreenType.PINNED) {
      setState(() {
        notes.decrementIndex();
        notes;
      });
    }
  }

  void handleListViewDeleteAction() {
    // TODO: 最新のclipboardと同じtextは消せないようにする
    if (type == ScreenType.CLIP) {
      clipRepository.deleteClip(clips.currentItem.id);

      setState(() {
        clips.deleteCurrentClip();
        clips = clips;
      });
    } else if (type == ScreenType.PINNED) {}
  }

  void copyToClipboard() {
    if (type == ScreenType.CLIP) {
      Clipboard.setData(ClipboardData(text: clips.currentItem.text));
    } else if (type == ScreenType.PINNED) {
      Clipboard.setData(ClipboardData(text: notes.currentItem.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appWidth = MediaQuery.of(context).size.width;
    const ratio1 = 0.15;
    const ratio2 = 0.85;
    const ratio3 = 0.3;
    const ratio4 = 0.7;
    return Scaffold(
        body: Center(
            child: FocusableActionDetector(
                autofocus: true,
                shortcuts: {
                  _listViewUpKeySet: _ListViewUpIntent(),
                  _listViewDownKeySet: _ListViewDownIntent(),
                  _listViewItemCopyKeySet: _ListViewItemCopyIntent(),
                  _listViewDeleteKeySet: _ListViewItemDeleteIntent()
                },
                actions: {
                  _ListViewUpIntent:
                      CallbackAction(onInvoke: (e) => handleListUp()),
                  _ListViewDownIntent:
                      CallbackAction(onInvoke: (e) => handleListDown()),
                  _ListViewItemCopyIntent:
                      CallbackAction(onInvoke: (e) => copyToClipboard()),
                  _ListViewItemDeleteIntent: CallbackAction(
                      onInvoke: (e) => handleListViewDeleteAction())
                },
                child: Row(children: [
                  Container(
                      color: side1stBackground,
                      width: appWidth * ratio1 - 2 - offset,
                      child: Stack(children: [
                        Column(children: [
                          Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              width: double.infinity,
                              color: type == ScreenType.CLIP
                                  ? side1stBackgroundSelect
                                  : side1stBackground,
                              child: IconText(
                                icon: Icons.history,
                                text: "history",
                                textColor: textColor,
                                iconColor: iconColor,
                                onTap: () => handleSideBarTap(ScreenType.CLIP),
                              )),
                          Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              width: double.infinity,
                              color: type == ScreenType.PINNED
                                  ? side1stBackgroundSelect
                                  : side1stBackground,
                              child: IconText(
                                icon: Icons.push_pin_sharp,
                                text: "pinned",
                                textColor: textColor,
                                iconColor: iconColor,
                                onTap: () =>
                                    handleSideBarTap(ScreenType.PINNED),
                              )),
                          Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              width: double.infinity,
                              color: type == ScreenType.TRASH
                                  ? side1stBackgroundSelect
                                  : side1stBackground,
                              child: IconText(
                                icon: Icons.delete,
                                text: "trash",
                                textColor: textColor,
                                iconColor: iconColor,
                                onTap: () => handleSideBarTap(ScreenType.TRASH),
                              )),
                        ]),
                        Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                color: type == ScreenType.SETTING
                                    ? side1stBackgroundSelect
                                    : side1stBackground,
                                child: IconText(
                                  icon: Icons.settings,
                                  text: "setting",
                                  textColor: textColor,
                                  iconColor: iconColor,
                                  onTap: () =>
                                      handleSideBarTap(ScreenType.SETTING),
                                ))),
                      ])),
                  MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                          onHorizontalDragStart: (detail) {
                            dragStartPos = detail.globalPosition.dx;
                          },
                          onHorizontalDragUpdate: (detail) {
                            final appWidth = MediaQuery.of(context).size.width;
                            double newOffset =
                                dragStartPos - detail.globalPosition.dx;
                            if (appWidth * ratio1 < newOffset ||
                                appWidth * ratio1 - newOffset > appWidth)
                              return;
                            setState(() => {
                                  offset =
                                      (dragStartPos - detail.globalPosition.dx)
                                });
                          },
                          child: Container(
                            width: 1,
                            color: dividerColor,
                          ))),
                  Container(
                      alignment: Alignment.topLeft,
                      width: appWidth * ratio2 + offset,
                      child: (() {
                        if (type == ScreenType.CLIP) {
                          if (clips.value.isEmpty) {
                            return const Text("clip is empty ;(");
                          } else {
                            return Row(children: <Widget>[
                              ContentsListView(
                                controller: listViewController,
                                width: (appWidth * ratio2 + offset) * ratio3,
                                onItemTap: (index) =>
                                    handleListViewItemTap(index),
                                items: clips.value,
                              ),
                              Container(
                                  alignment: Alignment.topLeft,
                                  width: (appWidth * ratio2 + offset) * ratio4,
                                  child: Column(children: [
                                    ContentsHeader(
                                        handleMoveToPinTap: () =>
                                            handleArchiveItemTap(),
                                        handleCopyToClipboardTap: () =>
                                            copyToClipboard(),
                                        handleMoveToTrashTap: () =>
                                            handleListViewDeleteAction()),
                                    // Expanded(
                                    //     child: Text(clips.currentItem.mdText))
                                    Markdown(
                                      controller: ScrollController(),
                                      shrinkWrap: true,
                                      selectable: true,
                                      builders: {'pre': CustomBlockBuilder()},
                                      data: clips.currentItem.mdText,
                                      extensionSet: md.ExtensionSet(
                                        md.ExtensionSet.gitHubFlavored
                                            .blockSyntaxes,
                                        [
                                          md.EmojiSyntax(),
                                          ...md.ExtensionSet.gitHubFlavored
                                              .inlineSyntaxes
                                        ],
                                      ),
                                    )
                                  ]))
                            ]);
                          }
                        } else if (type == ScreenType.PINNED) {
                          if (notes.value.isEmpty) {
                            return const Text("note is empty ;(");
                          } else {
                            return Row(children: <Widget>[
                              ContentsListView(
                                controller: listViewController,
                                width: (appWidth * ratio2 + offset) * ratio3,
                                onItemTap: (index) =>
                                    handleListViewItemTap(index),
                                items: notes.value,
                              ),
                              Container(
                                  alignment: Alignment.topLeft,
                                  width: (appWidth * ratio2 + offset) * ratio4,
                                  child: Column(children: [
                                    ContentsHeader(
                                        handleMoveToPinTap: () =>
                                            handleArchiveItemTap(),
                                        handleCopyToClipboardTap: () =>
                                            copyToClipboard(),
                                        handleMoveToTrashTap: () =>
                                            handleListViewDeleteAction()),
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 8, 16, 8),
                                            child: TextFormField(
                                                key: Key(notes.currentItem.id
                                                    .toString()),
                                                expands: true,
                                                maxLines: null,
                                                minLines: null,
                                                initialValue:
                                                    notes.currentItem.mdText)))
                                    // Markdown(
                                    //     controller: ScrollController(),
                                    //     shrinkWrap: true,
                                    //     data: notes.currentItem.mdText)
                                  ]))
                            ]);
                          }
                        } else if (type == ScreenType.TRASH) {
                          if (trashes.value.isEmpty) {
                            return const Text("trash is empty ;(");
                          } else {
                            return Row(children: <Widget>[
                              ContentsListView(
                                controller: listViewController,
                                width: (appWidth * ratio2 + offset) * ratio3,
                                onItemTap: (index) =>
                                    handleListViewItemTap(index),
                                items: trashes.value,
                              ),
                              Container(
                                  alignment: Alignment.topLeft,
                                  width: (appWidth * ratio2 + offset) * ratio4,
                                  child: Column(children: [
                                    ContentsHeader(
                                      handleMoveToPinTap: () =>
                                          handleArchiveItemTap(),
                                      handleCopyToClipboardTap: () =>
                                          copyToClipboard(),
                                      handleMoveToTrashTap: () =>
                                          handleListViewDeleteAction(),
                                    ),
                                    Markdown(
                                        controller: ScrollController(),
                                        shrinkWrap: true,
                                        data: trashes.currentItem.mdText)
                                  ]))
                            ]);
                          }
                        }
                      })())
                ]))));
  }
}

class _ListViewDownIntent extends Intent {}

class _ListViewUpIntent extends Intent {}

class _ListViewItemCopyIntent extends Intent {}

class _ListViewItemDeleteIntent extends Intent {}

final _listViewDownKeySet = LogicalKeySet(LogicalKeyboardKey.keyJ);
final _listViewUpKeySet = LogicalKeySet(LogicalKeyboardKey.keyK);
final _listViewItemCopyKeySet =
    LogicalKeySet(LogicalKeyboardKey.keyC, LogicalKeyboardKey.meta);
final _listViewDeleteKeySet = LogicalKeySet(LogicalKeyboardKey.keyD);
