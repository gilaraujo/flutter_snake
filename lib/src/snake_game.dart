import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_snake/src/snake_board.dart';

import 'snake_enums/snake_enums.dart';
import 'utils/utils.dart';

// ignore: must_be_immutable
class SnakeGame extends StatefulWidget {
  /// Direction for the next tick
  SNAKE_MOVE? _direction;

  /// Define the direction the snake will take on the next tick
  set nextDirection(SNAKE_MOVE move) => _direction = move;

  /// Get the next direction the snake will take on the next tick
  SNAKE_MOVE get getDirection => _direction ?? SNAKE_MOVE.front;

  late _SnakeGameState state;

  void restart() {
    state.initialize();
  }
  void pause() {
    state.pause();
  }

  /// Case width / height (It's a square)
  double caseWidth;

  /// Duration between each ticks
  final Duration durationBetweenTicks;

  /// Number of case horizontally (x)
  int numberCaseHorizontally;

  /// Number of case vertically (y)
  int numberCaseVertically;

  /// If defines, the controller stream receive the game event
  final StreamController<GAME_EVENT>? controllerEvent;

  /// Color variation for the background
  final Color colorBackground1;
  final Color colorBackground2;

  /// Snake image body and fruit
  final String? snakeHeadImgPath;
  final String? snakeBodyImgPath;
  final String? snakeBodyTurnImgPath;
  final String? snakeTailImgPath;
  final String? snakeFruitImgPath;
  final String? snakeBombImgPath;
  final bool bombEnabled;
  final SnakeBoard? current;

  SnakeGame({
    Key? key,
    required this.caseWidth,
    required this.numberCaseHorizontally,
    required this.numberCaseVertically,
    this.durationBetweenTicks = const Duration(milliseconds: 500),
    this.controllerEvent,
    this.colorBackground1 = Colors.greenAccent,
    this.colorBackground2 = Colors.green,
    this.snakeBodyImgPath,
    this.snakeBodyTurnImgPath,
    this.snakeTailImgPath,
    this.snakeFruitImgPath,
    this.snakeHeadImgPath,
    this.snakeBombImgPath,
    this.bombEnabled = false,
    this.current,
  }) : super(
          key: key,
        ) {
    if (numberCaseVertically < 4 || numberCaseHorizontally < 4) {
      throw ("Error SnakeGame: numberCaseVertically and numberCaseHorizontally can't be inferior of 10");
    }
  }

  @override
  _SnakeGameState createState() {
    this.state = _SnakeGameState();
    return this.state;
  }
}

class _SnakeGameState extends State<SnakeGame> {
  /// Manage the movement of the snake
  StreamController<SNAKE_MOVE>? controller;

  /// Board management
  SnakeBoard? _board;

  /// Loop for the game
  Timer? timer;

  @override
  void initState() {
    super.initState();

    initialize();
  }

  void initialize() {
    /// Init the board
    _board = widget.current ?? SnakeBoard(
      numberCaseHorizontally: widget.numberCaseHorizontally,
      numberCaseVertically: widget.numberCaseVertically,
      bombEnabled: widget.bombEnabled,
    );

    /// Init the controller
    if (controller == null) {
      controller = StreamController<SNAKE_MOVE>();
      /// and listen the events
      controller?.stream.listen((value) {
        _moveSnake(value);
      });
    }

    /// Defines the loop for the game
    timer?.cancel();
    _initTimer();
  }

  void _initTimer() {
    timer = Timer.periodic(widget.durationBetweenTicks, (Timer t) {
      controller?.add(widget.getDirection);
      widget.nextDirection = SNAKE_MOVE.front;
    });
  }

  void pause() {
    if (timer?.isActive ?? false) {
      timer?.cancel();
    } else {
      _initTimer();
    }
  }

  @override
  void dispose() {
    /// Dispose the timer.
    timer?.cancel();
    super.dispose();
  }

  _moveSnake(SNAKE_MOVE direction) {
    /// move the snake on the board
    GAME_EVENT? event = _board?.moveSnake(direction);
    if (!mounted) {
      return;
    }
    setState(() {});

    /// Check if a special event is returned
    if (event != null) {
      widget.controllerEvent?.add(event);

      /// Check if the game is finished
      if (event == GAME_EVENT.win ||
          event == GAME_EVENT.hit_his_tail ||
          event == GAME_EVENT.out_of_map ||
          event == GAME_EVENT.hit_bomb) {
        timer?.cancel();
        timer = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey,
      width: widget.caseWidth * widget.numberCaseHorizontally,
      height: widget.caseWidth * widget.numberCaseVertically,
      child: _printBoard(),
    );
  }

  /// Look all the board and print it (Board first, then the snake / fruit)
  Column _printBoard() {
    List<Widget> items = [];
    int y = 0;
    int x = 0;

    /// Check each line of the board
    while (_board?.getLine(y) != null) {
      List<Widget> tmp = [];
      x = 0;

      /// Get a specific case of the board (y, x)
      BoardCase? boardCase = _board?.getCase(y, x);

      /// Loop on each case of the line
      while (boardCase != null) {
        Color? colorCase;
        bool? defaultImg;
        String imgIcon = "";
        int quarterTurns = 0;

        /// Create the checkerboard with 2 colors
        colorCase = (x % 2 == 0 && y % 2 == 0) || (x % 2 == 1 && y % 2 == 1)
            ? widget.colorBackground1
            : widget.colorBackground2;

        /// Check if the case contain food
        switch (boardCase.caseType) {
          case CASE_TYPE.food:
            defaultImg = widget.snakeFruitImgPath == null;
            imgIcon =
                widget.snakeFruitImgPath ?? "assets/default_snake_fruit.png";
            break;
          case CASE_TYPE.bomb:
            defaultImg = widget.snakeBombImgPath == null;
            imgIcon =
                widget.snakeBombImgPath ?? "assets/default_snake_bomb.png";
            break;
          default:
        }

        /// Check if a snake is on it
        if (boardCase.partSnake != null) {
          /// Check his type
          switch (boardCase.partSnake!.type) {
            case SNAKE_BODY.head:
              defaultImg = widget.snakeHeadImgPath == null;
              imgIcon =
                  widget.snakeHeadImgPath ?? "assets/default_snake_head.png";
              quarterTurns = _rotateHead(boardCase.partSnake!);
              break;
            case SNAKE_BODY.tail:
              defaultImg = widget.snakeTailImgPath == null;
              imgIcon =
                  widget.snakeTailImgPath ?? "assets/default_snake_tail.png";
              quarterTurns = _rotateTail(boardCase.partSnake!);
              break;
            default:
              if (boardCase.partSnake!.previous!.posX ==
                      boardCase.partSnake!.next!.posX ||
                  boardCase.partSnake!.previous!.posY ==
                      boardCase.partSnake!.next!.posY) {
                defaultImg = widget.snakeBodyImgPath == null;
                quarterTurns = _rotateBody(boardCase.partSnake!);
                imgIcon =
                    widget.snakeBodyImgPath ?? "assets/default_snake_body.png";
              } else {
                defaultImg = widget.snakeBodyTurnImgPath == null;
                quarterTurns = _rotateBodyTurn(boardCase.partSnake!);
                imgIcon = widget.snakeBodyTurnImgPath ??
                    "assets/default_snake_turn.png";
              }
          }
        }
        tmp.add(
          Stack(
            children: [
              Container(
                width: widget.caseWidth,
                height: widget.caseWidth,
                color: colorCase,
              ),
              defaultImg != null
                  ? RotatedBox(
                      quarterTurns: quarterTurns,
                      child: defaultImg
                          ? Image.asset(
                              imgIcon,
                              width: widget.caseWidth,
                              height: widget.caseWidth,
                              package: 'flutter_snake',
                            )
                          : Image(
                              image: AssetImage(imgIcon),
                              width: widget.caseWidth,
                              height: widget.caseWidth,
                            ),
                    )
                  : Container(),
            ],
          ),
        );
        x++;
        boardCase = _board?.getCase(y, x);
      }
      items.add(
        Row(
          children: tmp,
        ),
      );
      y++;
    }

    return Column(
      children: items,
    );
  }

  /// Rotate the head depends on direction
  int _rotateHead(SnakePart partSnake) {
    if (partSnake.next!.posX == partSnake.posX) {
      if (partSnake.next!.posY < partSnake.posY) {
        return 3;
      } else {
        return 1;
      }
    } else {
      if (partSnake.next!.posX < partSnake.posX) {
        return 2;
      } else {
        return 0;
      }
    }
  }

  /// Rotate the tail depends on direction
  int _rotateTail(SnakePart partSnake) {
    if (partSnake.previous!.posX == partSnake.posX) {
      if (partSnake.previous!.posY < partSnake.posY) {
        return 0;
      } else {
        return 2;
      }
    } else {
      if (partSnake.previous!.posX < partSnake.posX) {
        return 3;
      } else {
        return 1;
      }
    }
  }

  /// Rotate the body depends on direction
  int _rotateBody(SnakePart partSnake) {
    if (partSnake.previous!.posX == partSnake.posX) {
      return 1;
    } else {
      return 0;
    }
  }

  /// Rotate the body turn depends on direction
  int _rotateBodyTurn(SnakePart partSnake) {
    SnakePart previous = partSnake.previous!;
    SnakePart next = partSnake.next!;

    SNAKE_DIRECTION directionPrevious =
        _rotateBodyTurnCheckDirection(partSnake, previous);
    SNAKE_DIRECTION directionNext =
        _rotateBodyTurnCheckDirection(partSnake, next);

    if (directionNext == SNAKE_DIRECTION.down &&
        directionPrevious == SNAKE_DIRECTION.right) {
      return 1;
    }
    if (directionNext == SNAKE_DIRECTION.down &&
        directionPrevious == SNAKE_DIRECTION.left) {
      return 2;
    }
    if (directionNext == SNAKE_DIRECTION.up &&
        directionPrevious == SNAKE_DIRECTION.left) {
      return 3;
    }
    if (directionNext == SNAKE_DIRECTION.left &&
        directionPrevious == SNAKE_DIRECTION.up) {
      return 3;
    }
    if (directionNext == SNAKE_DIRECTION.left &&
        directionPrevious == SNAKE_DIRECTION.down) {
      return 2;
    }
    if (directionNext == SNAKE_DIRECTION.right &&
        directionPrevious == SNAKE_DIRECTION.down) {
      return 1;
    }
    return 0;
  }

  /// return the direction of a snake part to another one.
  SNAKE_DIRECTION _rotateBodyTurnCheckDirection(
      SnakePart partSnake, SnakePart compare) {
    if (compare.posX == partSnake.posX) {
      if (compare.posY < partSnake.posY) {
        return SNAKE_DIRECTION.down;
      } else {
        return SNAKE_DIRECTION.up;
      }
    } else {
      if (compare.posX < partSnake.posX) {
        return SNAKE_DIRECTION.right;
      } else {
        return SNAKE_DIRECTION.left;
      }
    }
  }
}
