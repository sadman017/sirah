import 'package:connectivity/connectivity.dart';
import 'package:dartz/dartz.dart' as d;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sirah/app/pages/timeline/model/timeline.dart';
import 'package:sirah/app/pages/timeline/model/timeline_entry.dart';
import 'package:sirah/app/pages/timeline/repo/timeline_repo.dart';
import 'package:sirah/app/pages/timeline/widget/timeline_render_widget.dart';
import 'package:sirah/app/pages/timeline/util/timeline_utlis.dart';
import 'package:sirah/app/routes/routes.dart';
import 'package:sirah/shared/util/loader.dart';

typedef ShowMenuCallback = Function();

// enum FurtherActionEnum { routeToNextEvent, routeToPreviousEvent, doNothing }

class TimelineWidget extends StatefulWidget {
  // final ShowMenuCallback showMenu;
  const TimelineWidget({
    Key? key,
    this.timeline,
  }) : super(key: key);

  final Timeline? timeline;

  @override
  _TimelineWidgetState createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  Timeline? _timeline;

  Offset? _lastFocalPoint;
  double _scaleStartYearStart = -100.0;
  double _scaleStartYearEnd = 100.0;
  bool zooming = false;

  TapTarget? _touchedBubble;
  bool? _nextPressedInDetailsPage;

  final GlobalKey<ScaffoldState> _key = GlobalKey();

  @override
  void initState() {
    _getTimeline();
    super.initState();
  }

  // Future<void> _zoom({required bool zoomIn}) async {
  //   Offset _f = Offset(MediaQuery.of(context).size.width / 2,
  //       MediaQuery.of(context).size.height / 2);

  //   while (zooming) {
  //     _scaleStart(ScaleStartDetails(
  //       focalPoint: _f,
  //     ));
  //     _scaleUpdate(ScaleUpdateDetails(
  //       scale: zoomIn ? 1.1 : 0.9,
  //       horizontalScale: 1.0,
  //       verticalScale: 1.0,
  //       focalPoint: _f,
  //     ));
  //     await Future.delayed(const Duration(milliseconds: 100));
  //   }
  // }

  Future<void> _getTimeline() async {
    if (widget.timeline == null) {
      TimelineApi _api = HttpTimelineApi();
      d.Either<String, Timeline> _result =
          await _api.getTopicList(forceRefresh: true);
      _result.fold((String error) {
        if (kDebugMode) {
          print('show error');
        }
      }, (Timeline timeline) {
        _timeline = timeline;
        setState(() {});
      });
    } else {
      _timeline = widget.timeline;
    }
    scaleProper();
  }

  Future<void> scaleProper({double? start, double? end}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_timeline?.selectedId != null) {
      _focusOnEventByIndex(_getIndexFromEventId(_timeline?.selectedId) ?? 7);
    } else {
      _timeline?.setViewport(
          start: start ?? 564, end: end ?? 590, animate: true);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _scaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _scaleStartYearStart = _timeline!.start;
    _scaleStartYearEnd = _timeline!.end;
    _timeline!.isInteracting = true;
    _timeline!.setViewport(velocity: 0.0, animate: true);
  }

  void _tapUp(TapUpDetails details) async {
    if (_touchedBubble != null) {
      _timeline?.selectedId = _touchedBubble?.entry?.id;
      _nextPressedInDetailsPage = await Navigator.of(context)
          .pushNamed(Routes.topicDetails, arguments: <String, dynamic>{
        'article': _touchedBubble!.entry!,
        'timeline': _timeline,
      }) as bool;
      // await Future.delayed(const Duration(milliseconds: 500));
      _doFurtherAction();
    }
  }

  void _focusOnDesiredEntry({bool next = true}) {
    if (_timeline?.selectedId == null) {
      for (int i = 0; i < (_timeline?.allEntries.length ?? 0); i++) {
        if (_timeline?.allEntries[i].start == 570.5) {
          _timeline?.selectedId = _timeline?.allEntries[i].id;
        }
      }
    }
    int? _index = _getIndexFromEventId(_timeline?.selectedId);
    if (next == true) {
      if (_index == ((_timeline?.allEntries.length ?? 1) - 1)) {
        _index = 0;
      } else {
        _index = ((_index ?? 0) + 1);
      }
    }
    if (next == false) {
      if (_index == 0) {
        _index = (_timeline?.allEntries.length ?? 1) - 1;
      } else {
        _index = ((_index ?? 1) - 1);
      }
    }
    _timeline?.selectedId = _timeline?.allEntries[_index ?? 7].id;
    _focusOnEventByIndex(_index ?? 7);
  }

  int? _getIndexFromEventId(String? id) {
    for (int i = 0; i < (_timeline?.allEntries.length ?? 0); i++) {
      if (_timeline?.allEntries[i].id == id) {
        // _timeline?.selectedId = _timeline?.allEntries[i].id;
        return i;
      }
    }
    return null;
  }

  void _focusOnEventByIndex(int index) {
    double _year = _timeline?.allEntries[index].start ?? 570.5;
    double _distancePrev;
    if (index != 0) {
      _distancePrev = (_timeline?.allEntries[index].start ?? 0) -
          (_timeline?.allEntries[index - 1].start ?? 0);
    } else {
      _distancePrev = 999;
    }
    double _distanceNext;
    if (index >= (_timeline?.allEntries.length ?? 1) - 1) {
      _distanceNext = (_timeline?.allEntries[index + 1].start ?? 0) -
          (_timeline?.allEntries[index].start ?? 0);
    } else {
      _distanceNext = 999;
    }

    double _distance =
        _distancePrev > _distanceNext ? _distanceNext : _distancePrev;
    _distance = _distance + (_distance / 2);
    // Future.delayed(Duration(seconds: 0));
    // scaleProper(start: _year - _distance, end: _year + _distance);
    setState(() {
      _timeline?.setViewport(
          start: _year - _distance, end: _year + _distance, animate: true);
    });
    // Future.delayed(Duration(seconds: 0));
  }

  void _doFurtherAction() async {
    if (_nextPressedInDetailsPage == null) {
      return;
    }
    int? _index = _getIndexFromEventId(_timeline?.selectedId);
    if (_nextPressedInDetailsPage == true) {
      if (_index == ((_timeline?.allEntries.length ?? 1) - 1)) {
        _index = 0;
      } else {
        _index = ((_index ?? 0) + 1);
      }
    }
    if (_nextPressedInDetailsPage == false) {
      if (_index == 0) {
        _index = (_timeline?.allEntries.length ?? 1) - 1;
      } else {
        _index = ((_index ?? 1) - 1);
      }
    }
    _timeline?.selectedId = _timeline?.allEntries[_index ?? 7].id;
    _nextPressedInDetailsPage = null;
    _nextPressedInDetailsPage = await Navigator.of(context)
        .pushNamed(Routes.topicDetails, arguments: <String, dynamic>{
      'article': _timeline?.allEntries[_index ?? 7],
      'timeline': _timeline,
    }) as bool?;
    if (_nextPressedInDetailsPage != null) {
      _doFurtherAction();
    } else {
      _focusOnEventByIndex(_index ?? 7);
    }
  }

  onTouchBubble(TapTarget? bubble) {
    _touchedBubble = bubble;
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    double changeScale = details.scale;
    double scale =
        (_scaleStartYearEnd - _scaleStartYearStart) / context.size!.height;

    double focus = _scaleStartYearStart + details.focalPoint.dy * scale;
    double focalDiff =
        (_scaleStartYearStart + _lastFocalPoint!.dy * scale) - focus;

    _timeline!.setViewport(
        start: focus + (_scaleStartYearStart - focus) / changeScale + focalDiff,
        end: focus + (_scaleStartYearEnd - focus) / changeScale + focalDiff,
        height: context.size!.height,
        animate: true);
  }

  void _scaleEnd(ScaleEndDetails details) {
    double scale = (_timeline!.end - _timeline!.start) / context.size!.height;
    _timeline!.isInteracting = false;
    _timeline!.setViewport(
        velocity: details.velocity.pixelsPerSecond.dy * scale, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_timeline == null) {
      return Loader.circular();
    }

    return Scaffold(
      key: _key,
      drawer: _timeline?.allEntries == null ? null : _getDrawer(),
      body: GestureDetector(
        onScaleStart: _scaleStart,
        onScaleUpdate: _scaleUpdate,
        onScaleEnd: _scaleEnd,
        onTapUp: _tapUp,
        child: Stack(
          children: <Widget>[
            TimelineRenderWidget(
              timeline: _timeline!,
              touchBubble: onTouchBubble,
            ),
            Container(
              color: Colors.white,
              height: 56.0 + MediaQuery.of(context).padding.top,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                          onPressed: () {
                            _key.currentState?.openDrawer();
                          },
                          icon: Icon(
                            Icons.menu,
                            color: Colors.black.withOpacity(0.5),
                          )),
                      Container(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          'সিরাহ',
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.black.withOpacity(0.87)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(
                          Icons.home_outlined,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        tooltip: 'Reset',
                        onPressed: () async {
                          ConnectivityResult _connect =
                              await Connectivity().checkConnectivity();
                          if (_connect == ConnectivityResult.none) {
                            _timeline?.setViewport(
                                start: 564, end: 590, animate: true);
                          } else {
                            _getTimeline();
                          }
                          _timeline?.selectedId = null;
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline_rounded,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushNamed(Routes.topicDetails,
                              arguments: <String, dynamic>{
                                'article': TimelineEntry()
                                  ..label = 'আমাদের সম্পর্কে'
                                  ..articleFilename = 'about_us.txt',
                                'timeline': _timeline,
                              });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
            Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                child: _getNextPrev()),
          ],
        ),
      ),
    );
  }

  Widget? _getDrawer() {
    if (_timeline?.allEntries == null ||
        (_timeline?.allEntries.isEmpty ?? true)) {
      return null;
    }
    return Drawer(
      child: ListView.builder(
        itemCount: _timeline?.allEntries.length,
        itemBuilder: (BuildContext context, int index) {
          // if (index == 0) return DrawerHeader(child: Text('ArRijal Sirah App'));
          return GestureDetector(
            onTap: () {
              if (index < 1) {
                _timeline?.selectedId = _timeline?.allEntries[index + 1].id;
                Navigator.of(context).pop();
                _focusOnDesiredEntry(next: false);
              }
              _timeline?.selectedId = _timeline?.allEntries[index - 1].id;
              Navigator.of(context).pop();
              _focusOnDesiredEntry(next: true);
            },
            child: SizedBox(
              height: 56.0,
              child: Center(
                  child: Text(
                '${_timeline?.allEntries[index].label}',
                maxLines: 2,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _getNextPrev() {
    return SizedBox(
      // height: 100.0,
      width: 56.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          MaterialButton(
            height: 56,
            minWidth: 56,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: Colors.white,
            child: Icon(
              Icons.arrow_upward,
              color: Colors.black.withOpacity(0.5),
            ),
            onPressed: () {
              _focusOnDesiredEntry(next: false);
            },
          ),
          const SizedBox(height: 8),
          MaterialButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minWidth: 56,
            height: 56,
            color: Colors.white,
            child: Icon(
              Icons.arrow_downward,
              color: Colors.black.withOpacity(0.5),
            ),
            onPressed: () {
              _focusOnDesiredEntry(next: true);
            },
          ),
        ],
      ),
    );
  }
}
