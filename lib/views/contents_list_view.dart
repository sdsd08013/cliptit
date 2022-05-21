import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../color.dart';

typedef Int2VoidFunc = void Function(int);

class ContentsListView extends StatelessWidget {
  final width;
  final ScrollController controller;
  final Int2VoidFunc onItemTap;
  final items;
  ContentsListView(
      {required this.width,
      required this.controller,
      required this.items,
      required this.onItemTap});
  @override
  Widget build(BuildContext context) {
    return Container(
        color: side2ndBackground,
        width: width,
        child: ListView.separated(
          controller: controller,
          itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                onItemTap.call(index);
              },
              child: Container(
                  padding: const EdgeInsets.all(8),
                  color: items[index].isSelected
                      ? side2ndBackgroundSelect
                      : side2ndBackground,
                  child: RichText(
                    text: TextSpan(
                      text: items[index].subText(),
                      style: const TextStyle(color: textColor),
                    ),
                  ))),
          separatorBuilder: (context, index) =>
              const Divider(color: dividerColor, height: 0.5),
          itemCount: items.length,
        ));
  }
}
