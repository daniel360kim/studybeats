import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';

class ListInformation extends StatefulWidget {
  ListInformation({required this.todoList, super.key}) {
    formattedName = todoList.name.length > 14
        ? '${todoList.name.substring(0, 14)}...'
        : todoList.name;
  }

  final TodoList todoList;
  late final String formattedName;
  @override
  State<ListInformation> createState() => _ListInformationState();
}

class _ListInformationState extends State<ListInformation> {
  @override
  Widget build(BuildContext context) {
    final todoCount = widget.todoList.categories.uncompleted.length;
    final completedCount = widget.todoList.categories.completed.length;
    final totalCount = todoCount + completedCount;
    final Color themeColor =
        Color(int.parse(widget.todoList.themeColor, radix: 16));
    return Container(
      height: 150,
      width: 125,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[350]!,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                todoCount == 1 ? '1 task' : '$todoCount tasks',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: kFlourishBlackish,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
          const SizedBox(
            height: 7.0,
          ),
          Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: ShapeDecoration(
                  color: themeColor,
                  shape: const CircleBorder(),
                ),
                child: const Icon(
                  // TODO add icons for each category
                  Icons.list,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                widget.formattedName,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: widget.formattedName.length > 10 ? 12 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              SizedBox(
                width: totalCount > 10
                    ? 80
                    : 90, // TODO allow for more than 100 tasks
                child: LinearProgressIndicator(
                  color: themeColor,
                  value: totalCount == 0 ? 0 : todoCount / totalCount,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                '$todoCount / $totalCount',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: Colors.black,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
          /*
          if (widget.showExpandedIcons)
            SingleChildScrollView(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CupertinoButton(
                    onPressed: widget.onEditPressed,
                    child: Text(
                      'Edit',
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      widget.onViewPressed();
                    },
                    child: Text(
                      'View',
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                    ),
                  )
                ],
              ),
            ),
            */
        ],
      ),
    );
  }
}
