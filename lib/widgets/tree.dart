import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:rfw/rfw.dart';
import 'package:url_launcher/url_launcher.dart';

class RFWTreeNode {
  RFWTreeNode({
    required this.title,
    this.libraryName,
    this.widgetName,
  });

  final String title;

  // Not null if this node represents a library or a widget.
  final LibraryName? libraryName;

  // Not null if this node represents a widget.
  final String? widgetName;

  final List<RFWTreeNode> children = [];
}

class RFWTreeView extends StatefulWidget {
  const RFWTreeView({super.key, required this.runtime});

  final Runtime runtime;

  @override
  State<RFWTreeView> createState() => _RFWTreeViewState();
}

class _RFWTreeViewState extends State<RFWTreeView> {
  final List<RFWTreeNode> roots = <RFWTreeNode>[];

  // This controller is responsible for both providing your hierarchical data
  // to tree views and also manipulate the states of your tree nodes.
  late final TreeController<RFWTreeNode> treeController;

  TreeSearchResult<RFWTreeNode>? filter;
  Pattern? searchPattern;
  late final TextEditingController searchBarTextEditingController;

  Iterable<RFWTreeNode> getChildren(RFWTreeNode node) {
    if (filter case TreeSearchResult<RFWTreeNode> filter?) {
      return node.children.where(filter.hasMatch);
    }
    return node.children;
  }

  void search(String query) {
    // Needs to be reset before searching again, otherwise the tree controller
    // wouldn't reach some nodes because of the `getChildren()` impl above.
    filter = null;

    Pattern pattern;
    try {
      pattern = RegExp(query);
    } on FormatException {
      pattern = query;
    }
    searchPattern = pattern;

    filter = treeController
        .search((RFWTreeNode node) => node.title.contains(pattern));
    treeController.rebuild();

    if (mounted) {
      setState(() {});
    }
  }

  void clearSearch() {
    if (filter == null) return;

    setState(() {
      filter = null;
      searchPattern = null;
      treeController.rebuild();
      searchBarTextEditingController.clear();
    });
  }

  void onSearchQueryChanged() {
    final String query = searchBarTextEditingController.text.trim();

    if (query.isEmpty) {
      clearSearch();
      return;
    }

    search(query);
  }

  @override
  void initState() {
    super.initState();
    searchBarTextEditingController = TextEditingController();
    searchBarTextEditingController.addListener(onSearchQueryChanged);
    final localLibraryNode = RFWTreeNode(title: 'Local');
    roots.add(localLibraryNode);
    final remoteLibraryNode = RFWTreeNode(title: 'Remote');
    roots.add(remoteLibraryNode);
    widget.runtime.libraries.forEach((libraryName, widgetLibrary) {
      final libraryNode =
          RFWTreeNode(title: '$libraryName', libraryName: libraryName);
      if (widgetLibrary is LocalWidgetLibrary) {
        localLibraryNode.children.add(libraryNode);
        widgetLibrary.widgets.forEach((widgetName, value) {
          final widgetNode = RFWTreeNode(
              title: widgetName,
              libraryName: libraryName,
              widgetName: widgetName);
          libraryNode.children.add(widgetNode);
        });
      } else if (widgetLibrary is RemoteWidgetLibrary) {
        remoteLibraryNode.children.add(libraryNode);
        for (final WidgetDeclaration widgetDeclaration
            in widgetLibrary.widgets) {
          final widgetNode = RFWTreeNode(
              title: widgetDeclaration.name,
              libraryName: libraryName,
              widgetName: widgetDeclaration.name);
          libraryNode.children.add(widgetNode);
        }
      } else {
        assert(false, 'unknown WidgetLibrary type ${libraryNode.runtimeType}');
      }
      libraryNode.children.sort((a, b) => a.title.compareTo(b.title));
    });
    localLibraryNode.children.sort((a, b) => a.title.compareTo(b.title));
    remoteLibraryNode.children.sort((a, b) => a.title.compareTo(b.title));
    treeController = TreeController<RFWTreeNode>(
      // Provide the root nodes that will be used as a starting point when
      // traversing your hierarchical data.
      roots: roots,
      // Provide a callback for the controller to get the children of a
      // given node when traversing your hierarchical data. Avoid doing
      // heavy computations in this method, it should behave like a getter.
      childrenProvider: (RFWTreeNode node) => node.children,
    );
  }

  @override
  void dispose() {
    filter = null;
    searchPattern = null;
    treeController.dispose();
    searchBarTextEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SearchBar(
          controller: searchBarTextEditingController,
          hintText: 'Type to Filter',
          leading: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.filter_list),
          ),
          trailing: [
            Badge(
              isLabelVisible: filter != null,
              label: Text(
                '${filter?.totalMatchCount}/${filter?.totalNodeCount}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: clearSearch,
            )
          ],
        ),
      ),
      Expanded(
          child: TreeView<RFWTreeNode>(
              // This controller is used by tree views to build a flat representation
              // of a tree structure so it can be lazy rendered by a SliverList.
              // It is also used to store and manipulate the different states of the
              // tree nodes.
              treeController: treeController,
              // Provide a widget builder callback to map your tree nodes into widgets.
              nodeBuilder:
                  (BuildContext context, TreeEntry<RFWTreeNode> entry) {
                // Provide a widget to display your tree nodes in the tree view.
                //
                // Can be any widget, just make sure to include a [TreeIndentation]
                // within its widget subtree to properly indent your tree nodes.
                return RFWTreeTile(
                  // Add a key to your tiles to avoid syncing descendant animations.
                  key: ValueKey(entry.node),
                  // Your tree nodes are wrapped in TreeEntry instances when traversing
                  // the tree, these objects hold important details about its node
                  // relative to the tree, like: expansion state, level, parent, etc.
                  //
                  // TreeEntrys are short lived, each time TreeController.rebuild is
                  // called, a new TreeEntry is created for each node so its properties
                  // are always up to date.
                  entry: entry,
                  // Add a callback to toggle the expansion state of this node.
                  onTap: () => treeController.toggleExpansion(entry.node),
                  match: filter?.matchOf(entry.node),
                  searchPattern: searchPattern,
                );
              }))
    ]);
  }
}

// Create a widget to display the data held by your tree nodes.
class RFWTreeTile extends StatefulWidget {
  const RFWTreeTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.match,
    this.searchPattern,
  });

  final TreeEntry<RFWTreeNode> entry;
  final VoidCallback onTap;
  final TreeSearchMatch? match;
  final Pattern? searchPattern;

  @override
  State<RFWTreeTile> createState() => _RFWTreeTileState();
}

class _RFWTreeTileState extends State<RFWTreeTile> {
  late InlineSpan titleSpan;

  TextStyle? dimStyle;
  TextStyle? highlightStyle;

  bool get shouldShowBadge =>
      !widget.entry.isExpanded && (widget.match?.subtreeMatchCount ?? 0) > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setupTextStyles();
    titleSpan = buildTextSpan();
  }

  @override
  void didUpdateWidget(covariant RFWTreeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchPattern != widget.searchPattern ||
        oldWidget.entry.node.title != widget.entry.node.title) {
      titleSpan = buildTextSpan();
    }
  }

  void setupTextStyles() {
    final TextStyle style = DefaultTextStyle.of(context).style;
    final Color highlightColor = Theme.of(context).colorScheme.primary;
    highlightStyle = style.copyWith(
      color: highlightColor,
      decorationColor: highlightColor,
      decoration: TextDecoration.underline,
    );
    dimStyle = style.copyWith(color: style.color?.withAlpha(128));
  }

  InlineSpan buildTextSpan() {
    final String title = widget.entry.node.title;

    if (widget.searchPattern == null) {
      return TextSpan(text: title);
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    bool hasAnyMatches = false;

    title.splitMapJoin(
      widget.searchPattern!,
      onMatch: (Match match) {
        hasAnyMatches = true;
        spans.add(TextSpan(text: match.group(0)!, style: highlightStyle));
        return '';
      },
      onNonMatch: (String text) {
        spans.add(TextSpan(text: text));
        return '';
      },
    );

    if (hasAnyMatches) {
      return TextSpan(children: spans);
    }

    return TextSpan(text: title, style: dimStyle);
  }

  @override
  Widget build(BuildContext context) {
    return TreeIndentation(
      entry: widget.entry,
      child: Row(
        children: [
          if (widget.entry.hasChildren)
            ExpandIcon(
              key: ValueKey(widget.entry.node),
              isExpanded: widget.entry.isExpanded,
              onPressed: (_) => TreeViewScope.of<RFWTreeNode>(context)
                ..controller.toggleExpansion(widget.entry.node),
            ),
          if (!widget.entry.hasChildren)
            const Icon(Icons.auto_awesome_mosaic_outlined, color: Colors.amber),
          if (shouldShowBadge)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Badge(
                label: Text('${widget.match?.subtreeMatchCount}'),
              ),
            ),
          InkWell(
              child: RichText(
                text: titleSpan,
              ),
              onTap: () {
                final libraryName = widget.entry.node.libraryName;
                final widgetName = widget.entry.node.widgetName;
                Uri? uri;
                if (libraryName != null && widgetName != null) {
                  if (libraryName.toString() == 'core.widgets') {
                    uri = Uri.https('api.flutter.dev',
                        '/flutter/widgets/$widgetName-class.html');
                  } else if (libraryName.toString() == 'material.widgets') {
                    uri = Uri.https('api.flutter.dev',
                        '/flutter/material/$widgetName-class.html');
                  }
                }
                if (uri == null) {
                  return;
                }
                launchUrl(uri);
              })
        ],
      ),
    );
  }
}
