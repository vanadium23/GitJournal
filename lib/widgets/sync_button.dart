import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';

import 'package:gitjournal/appstate.dart';
import 'package:gitjournal/state_container.dart';
import 'package:gitjournal/utils.dart';
import 'package:provider/provider.dart';

class SyncButton extends StatefulWidget {
  @override
  _SyncButtonState createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  StreamSubscription<ConnectivityResult> subscription;
  ConnectivityResult _connectivity;

  @override
  void initState() {
    super.initState();
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      setState(() {
        _connectivity = result;
      });
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<StateContainer>(context).appState;

    if (_connectivity == ConnectivityResult.none) {
      return IconButton(
        icon: Icon(Icons.signal_wifi_off),
        onPressed: () async {
          _syncRepo();
        },
      );
    }
    if (appState.syncStatus == SyncStatus.Loading) {
      return RotatingIcon();
    }

    return IconButton(
      icon: Icon(_syncStatusIcon()),
      onPressed: () async {
        _syncRepo();
      },
    );
  }

  void _syncRepo() async {
    try {
      final container = Provider.of<StateContainer>(context, listen: false);
      await container.syncNotes();
    } catch (e) {
      showSnackbar(context, e.toString());
    }
  }

  IconData _syncStatusIcon() {
    final container = Provider.of<StateContainer>(context);
    final appState = container.appState;
    switch (appState.syncStatus) {
      case SyncStatus.Error:
        return Icons.cloud_off;

      case SyncStatus.Unknown:
      case SyncStatus.Done:
      default:
        return Icons.cloud_done;
    }
  }
}

class RotatingIcon extends StatefulWidget {
  @override
  _RotatingIconState createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var button = IconButton(
      icon: const Icon(Icons.loop),
      onPressed: () {},
    );

    return RotationTransition(
      child: button,
      turns: _animation,
    );
  }
}
