import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/side_widgets/side_widget_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/studyroom/side_tiles/tiles/side_widget_tile.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:studybeats/api/side_widgets/objects.dart';

class TodoTile extends SideWidgetTile {
  const TodoTile({required super.settings, super.key});
  TodoTile.withDefaults({super.key})
      : super(
            settings: SideWidgetSettings(
          type: SideWidgetType.todo,
          title: 'Tasks',
          description: 'Shows your tasks',
          size: {
            'width': 1,
            'height': 1,
          },
          // Generate a unique widget ID
          widgetId: Uuid().v4(),

          data: {
            'theme': 'default',
          },
        ));

  @override
  State<TodoTile> createState() => _TodoTileState();

  @override
  SideWidgetSettings get defaultSettings {
    return SideWidgetSettings(
      widgetId: Uuid().v4(),
      title: 'Tasks',
      description: 'Shows your tasks',
      type: SideWidgetType.todo,
      size: {'width': 1, 'height': 1},
      data: {
        'theme': 'default',
      },
    );
  }
}

class _TodoTileState extends State<TodoTile> {
  bool doneLoading = false;
  bool todosDoneLoading = false;
  bool error = false;
  Map<String, dynamic> data = {};
  final TodoService todoService = TodoService();
  final TodoListService todoListService = TodoListService();

  List<TodoList>? _todoLists;
  List<TodoItem>? _uncompletedTodoItems;
  String? _selectedListId;

  bool _lastPanelOpen = false;
  final bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    init();
    getTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPanelOpen = context.watch<SidePanelController>().isOpen;
    if (isPanelOpen && !_lastPanelOpen) {
      getTasks(); // refresh tasks when panel opens
    }
    _lastPanelOpen = isPanelOpen;
  }

  void init() async {
    try {
      data = await widget.loadSettings(SideWidgetService());
      setState(() {
        doneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
      });
    }
  }

  void getTasks() async {
    try {
      if (!_servicesInitialized) {
        await todoService.init();
        await todoListService.init();
      }
      final todoLists = await todoListService.fetchTodoLists();

      final uncompletedTodoItems = todoLists.first.categories.uncompleted;
      setState(() {
        _todoLists = todoLists;
        _uncompletedTodoItems = uncompletedTodoItems;
        _selectedListId = todoLists.first.id; // Default to the first list
        todosDoneLoading = true;
      });
    } catch (e) {
      setState(() {
        error = true;
      });
    }
  }

  Widget _buildTileContainer({required Widget child}) {
    final theme = data['theme'];
    final isDark = theme == 'dark';
    return Container(
      width: kTileUnitWidth,
      height: kTileUnitHeight,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildContent({required bool isLoading}) {
    final theme = data['theme'];
    final isDark = theme == 'dark';
    final todoItems = _uncompletedTodoItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kFlourishAdobe,
              ),
            ),
            Text(
              '${todoItems?.length ?? 0}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading || todoItems == null)
          SizedBox()
        else if (todoItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Text(
                "You're all caught up!",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: todoItems.length,
              itemBuilder: (context, index) {
                final todoItem = todoItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todoItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: isDark ? Colors.white10 : Colors.black12,
                        indent: 30,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error) {
      return showErrorContainer();
    }
    return GestureDetector(
      onTap: () {
        // Open the todo list in the toolbar
        Provider.of<StudyToolbarController>(context, listen: false)
            .openOption(NavigationOption.todo);

        // Close the side panel if it's open
        Provider.of<SidePanelController>(context, listen: false).close();
      },
      child: _buildTileContainer(
        child: _buildContent(isLoading: !doneLoading || !todosDoneLoading),
      ),
    );
  }
}
