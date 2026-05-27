import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:chameleon_puzzle_demo/game/chameleon_puzzle_game.dart';
import 'package:chameleon_puzzle_demo/game/levels/demo_levels.dart';
import 'package:chameleon_puzzle_demo/game/models/board_cell.dart';
import 'package:chameleon_puzzle_demo/game/models/board_piece.dart';
import 'package:chameleon_puzzle_demo/game/models/board_state.dart';
import 'package:chameleon_puzzle_demo/game/models/bug_color.dart';
import 'package:chameleon_puzzle_demo/game/models/chameleon_state.dart';
import 'package:chameleon_puzzle_demo/game/models/game_mode.dart';
import 'package:chameleon_puzzle_demo/game/models/game_save.dart';
import 'package:chameleon_puzzle_demo/game/models/level_set_id.dart';
import 'package:chameleon_puzzle_demo/game/models/objective.dart';
import 'package:chameleon_puzzle_demo/game/models/objective_progress.dart';
import 'package:chameleon_puzzle_demo/game/models/player_progress.dart';
import 'package:chameleon_puzzle_demo/game/models/power_up.dart';
import 'package:chameleon_puzzle_demo/game/systems/match_system.dart';
import 'package:chameleon_puzzle_demo/game/systems/power_up_system.dart';
import 'package:chameleon_puzzle_demo/game/systems/pressure_row_generator.dart';

void main() {
  group('ChameleonState', () {
    test('same-color second swallow creates a glowing held bug', () {
      final chameleon = ChameleonState(columnIndex: 0);

      chameleon.holdFirst(BugColor.blue);
      expect(chameleon.canSwallow, isTrue);

      chameleon.holdSecond(BugColor.blue);
      expect(chameleon.heldColor, BugColor.blue);
      expect(chameleon.heldCharged, isTrue);
      expect(chameleon.canSwallow, isFalse);
    });

    test('glowing held bugs cannot swallow more bugs', () {
      final chameleon = ChameleonState(columnIndex: 0);

      chameleon.holdFirst(BugColor.purple, charged: true);

      expect(chameleon.heldColor, BugColor.purple);
      expect(chameleon.heldCharged, isTrue);
      expect(chameleon.canSwallow, isFalse);
    });
  });

  group('MatchSystem detonations', () {
    test('normal connected groups do not clear without a glowing bug', () {
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.blue), const BoardPiece(BugColor.blue)],
        [const BoardPiece(BugColor.blue)],
        [],
        [],
        [],
      ]);

      final groups = MatchSystem().findDetonations(board);

      expect(groups, isEmpty);
    });

    test('lone glowing bug does not clear', () {
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.blue, charged: true)],
        [],
        [],
        [],
        [],
      ]);

      final groups = MatchSystem().findDetonations(board);

      expect(groups, isEmpty);
    });

    test('glowing pair does not clear without a third matching bug', () {
      final board = BoardState.fromPieces([
        [
          const BoardPiece(BugColor.blue, charged: true),
          const BoardPiece(BugColor.blue),
        ],
        [],
        [],
        [],
        [],
      ]);

      final groups = MatchSystem().findDetonations(board);

      expect(groups, isEmpty);
    });

    test('glowing bug clears the full connected same-color group of three', () {
      final board = BoardState.fromPieces([
        [
          const BoardPiece(BugColor.blue, charged: true),
          const BoardPiece(BugColor.blue),
        ],
        [const BoardPiece(BugColor.blue)],
        [const BoardPiece(BugColor.red), const BoardPiece(BugColor.blue)],
        [],
        [],
      ]);

      final groups = MatchSystem().findDetonations(board);

      expect(groups, hasLength(1));
      expect(groups.single, {
        const BoardCell(0, 0),
        const BoardCell(0, 1),
        const BoardCell(1, 0),
      });
    });

    test('minimum of three enables staged red into blue chain setup', () {
      final board = BoardState.fromPieces([
        [
          const BoardPiece(BugColor.blue),
          const BoardPiece(BugColor.blue),
          const BoardPiece(BugColor.red),
          const BoardPiece(BugColor.blue, charged: true),
        ],
        [
          const BoardPiece(BugColor.yellow),
          const BoardPiece(BugColor.yellow),
          const BoardPiece(BugColor.red),
        ],
        [
          const BoardPiece(BugColor.orange),
          const BoardPiece(BugColor.orange),
          const BoardPiece(BugColor.red, charged: true),
        ],
        [],
        [],
      ]);
      final matchSystem = MatchSystem();

      final firstGroups = matchSystem.findDetonations(board);

      expect(firstGroups, hasLength(1));
      expect(firstGroups.single, {
        const BoardCell(0, 2),
        const BoardCell(1, 2),
        const BoardCell(2, 2),
      });

      board.clearCells(firstGroups.single);

      final secondGroups = matchSystem.findDetonations(board);

      expect(secondGroups, hasLength(1));
      expect(secondGroups.single, {
        const BoardCell(0, 0),
        const BoardCell(0, 1),
        const BoardCell(0, 2),
      });
    });

    test('diagonal-only contact does not clear', () {
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.blue, charged: true)],
        [const BoardPiece(BugColor.red), const BoardPiece(BugColor.blue)],
        [],
        [],
        [],
      ]);

      final groups = MatchSystem().findDetonations(board);

      expect(groups, isEmpty);
    });
  });

  group('BIG bugs', () {
    test('2x2 same-color normal bugs promote into a BIG bug', () {
      final board = BoardState([
        [BugColor.orange, BugColor.orange],
        [BugColor.orange, BugColor.orange],
        [],
        [],
        [],
      ]);
      final promotion = MatchSystem().findBigPromotions(board).single;

      board.promoteBigBlock(
        column: promotion.column,
        row: promotion.row,
        bigId: 1,
      );

      expect(board.pieceAt(0, 0)!.isBigAnchor, isTrue);
      expect(board.pieceAt(1, 0)!.isBigPart, isTrue);
      expect(board.pieceAt(0, 1)!.isBigPart, isTrue);
      expect(board.pieceAt(1, 1)!.isBigPart, isTrue);
    });

    test('charged or already BIG bugs do not promote into another BIG bug', () {
      final board = BoardState.fromPieces([
        [
          const BoardPiece(BugColor.orange, charged: true),
          const BoardPiece(BugColor.orange),
        ],
        [const BoardPiece(BugColor.orange), const BoardPiece(BugColor.orange)],
        [],
        [],
        [],
      ]);

      expect(MatchSystem().findBigPromotions(board), isEmpty);
    });

    test('BIG bug clears through a connected same-color glowing chain', () {
      final board = BoardState([
        [BugColor.red, BugColor.red],
        [BugColor.red, BugColor.red],
        [BugColor.red],
        [BugColor.red],
        [],
      ]);
      final promotion = MatchSystem().findBigPromotions(board).single;
      board.promoteBigBlock(
        column: promotion.column,
        row: promotion.row,
        bigId: 1,
      );
      board.insertPieceBottom(3, const BoardPiece(BugColor.red, charged: true));

      final groups = MatchSystem().findDetonations(board);

      expect(groups, hasLength(1));
      expect(groups.single, contains(const BoardCell(0, 0)));
      expect(groups.single, contains(const BoardCell(1, 1)));
      expect(groups.single, contains(const BoardCell(3, 0)));
    });

    test('BIG bugs cannot be swallowed', () {
      final piece = const BoardPiece(
        BugColor.red,
        type: BoardPieceType.bigAnchor,
        bigId: 1,
      );

      expect(piece.canSwallow, isFalse);
      expect(piece.clearValue, greaterThan(2));
    });

    test('clearing above one side splits a BIG bug into normal bugs', () {
      final board = BoardState([
        [BugColor.blue, BugColor.orange, BugColor.orange],
        [BugColor.yellow, BugColor.orange, BugColor.orange],
        [],
        [],
        [],
      ]);
      board.promoteBigBlock(column: 0, row: 1, bigId: 1);

      final result = board.clearCellsWithResult({const BoardCell(0, 0)});

      expect(result.removed, hasLength(1));
      expect(result.removed.single.color, BugColor.blue);
      expect(result.removed.single.isBig, isFalse);
      expect(result.bigSplits.map((split) => split.bigId), [1]);
      expect(board.cellsForBig(1), isEmpty);
      for (final cell in [
        const BoardCell(0, 0),
        const BoardCell(0, 1),
        const BoardCell(1, 1),
        const BoardCell(1, 2),
      ]) {
        final piece = board.pieceAt(cell.column, cell.row);
        expect(piece?.color, BugColor.orange);
        expect(piece?.isBig, isFalse);
      }
    });

    test('clearing a BIG bug cell still removes the whole BIG bug', () {
      final board = BoardState([
        [BugColor.orange, BugColor.orange],
        [BugColor.orange, BugColor.orange],
        [],
        [],
        [],
      ]);
      board.promoteBigBlock(column: 0, row: 0, bigId: 1);

      final result = board.clearCellsWithResult({const BoardCell(0, 0)});

      expect(result.removed, hasLength(4));
      expect(result.bigSplits, isEmpty);
      expect(board.cellsForBig(1), isEmpty);
    });

    test('synchronized top rows preserve BIG bug shape', () {
      final board = BoardState([
        [BugColor.red, BugColor.red],
        [BugColor.red, BugColor.red],
        [],
        [],
        [],
      ]);
      board.promoteBigBlock(column: 0, row: 0, bigId: 1);

      board.insertTopRow([
        const BoardPiece(BugColor.blue),
        const BoardPiece(BugColor.yellow),
        const BoardPiece(BugColor.orange),
        const BoardPiece(BugColor.purple),
        const BoardPiece(BugColor.red),
        const BoardPiece(BugColor.blue),
      ]);

      expect(board.pieceAt(0, 1)!.isBigAnchor, isTrue);
      expect(board.pieceAt(1, 1)!.isBigPart, isTrue);
      expect(board.pieceAt(0, 2)!.isBigPart, isTrue);
      expect(board.pieceAt(1, 2)!.isBigPart, isTrue);
    });
  });

  test('active gameplay colors exclude green', () {
    expect(BugColor.active, [
      BugColor.red,
      BugColor.blue,
      BugColor.yellow,
      BugColor.orange,
      BugColor.purple,
    ]);
  });

  test('spit attaches to the bottom of a hanging column', () {
    final board = BoardState([
      [BugColor.blue, BugColor.red, BugColor.yellow],
      [],
      [],
      [],
      [],
    ]);

    board.insertBottom(0, BugColor.purple);

    expect(board.columns[0].map((piece) => piece.color), [
      BugColor.blue,
      BugColor.red,
      BugColor.yellow,
      BugColor.purple,
    ]);
  });

  test('swallow removes the lowest bug from a hanging column', () {
    final board = BoardState([
      [BugColor.blue, BugColor.red, BugColor.yellow],
      [],
      [],
      [],
      [],
    ]);

    final removed = board.removeBottom(0);

    expect(removed.color, BugColor.yellow);
    expect(board.columns[0].map((piece) => piece.color), [
      BugColor.blue,
      BugColor.red,
    ]);
  });

  group('drag eligibility', () {
    test('allows a non-lowest bug with one open horizontal side', () {
      final board = BoardState([
        [BugColor.red],
        [BugColor.red, BugColor.red, BugColor.red],
        [BugColor.red],
        [],
        [],
        [],
      ]);

      expect(board.canDragPieceAt(1, 0), isFalse);
      expect(board.canDragPieceAt(1, 1), isTrue);
      expect(board.canDragPieceAt(1, 2), isTrue);
    });

    test('does not count outside the board as open space', () {
      final board = BoardState([
        [BugColor.red, BugColor.blue],
        [BugColor.yellow, BugColor.purple],
        [],
        [],
        [],
        [],
      ]);

      expect(board.canDragPieceAt(0, 0), isFalse);
      expect(board.canDragPieceAt(0, 1), isTrue);
    });

    test('blocks bugs that would shift a BIG bug below them', () {
      final board = BoardState([
        [BugColor.purple],
        [BugColor.red, BugColor.blue, BugColor.blue],
        [BugColor.red, BugColor.blue, BugColor.blue],
        [BugColor.red],
        [],
        [],
      ]);
      board.promoteBigBlock(column: 1, row: 1, bigId: 1);

      expect(board.canDragPieceAt(1, 0), isFalse);
      expect(board.canDragPieceAt(2, 0), isFalse);
      expect(board.canDragPieceAt(3, 0), isTrue);
    });

    test('removing a middle dragged bug collapses lower bugs upward', () {
      final board = BoardState([
        [BugColor.blue, BugColor.red, BugColor.yellow],
        [],
        [],
        [],
        [],
        [],
      ]);

      final removed = board.removePieceAt(0, 1);

      expect(removed.color, BugColor.red);
      expect(board.columns[0].map((piece) => piece.color), [
        BugColor.blue,
        BugColor.yellow,
      ]);
    });

    test('detects whether the board has a glow merge move', () {
      final stuck = BoardState([
        [BugColor.blue],
        [BugColor.yellow],
        [BugColor.purple],
        [BugColor.orange],
        [],
        [],
      ]);

      final playable = BoardState([
        [BugColor.blue],
        [BugColor.yellow, BugColor.red],
        [BugColor.red],
        [],
        [],
        [],
      ]);

      expect(stuck.hasGlowMergeMove(), isFalse);
      expect(playable.hasGlowMergeMove(), isTrue);
    });

    test('progress move detection counts dragging a glow into a pair', () {
      final board = BoardState.fromPieces([
        [const BoardPiece(BugColor.red)],
        [const BoardPiece(BugColor.blue)],
        [const BoardPiece(BugColor.orange, charged: true)],
        [const BoardPiece(BugColor.yellow)],
        [const BoardPiece(BugColor.orange), const BoardPiece(BugColor.orange)],
        [const BoardPiece(BugColor.purple)],
      ]);
      final matchSystem = MatchSystem();

      expect(matchSystem.findDetonations(board), isEmpty);
      expect(board.hasGlowMergeMove(), isFalse);
      expect(matchSystem.hasProgressMove(board), isTrue);
    });

    test('same-column merge can move a lower bug upward into a glow', () {
      final board = BoardState([
        [BugColor.blue, BugColor.blue, BugColor.blue],
        [],
        [],
        [],
        [],
        [],
      ]);

      board.mergePieceAt(
        sourceColumn: 0,
        sourceRow: 2,
        targetColumn: 0,
        targetRow: 1,
      );

      expect(board.columns[0], hasLength(2));
      expect(board.pieceAt(0, 0)!.charged, isFalse);
      expect(board.pieceAt(0, 1)!.charged, isTrue);
      expect(board.pieceAt(0, 1)!.color, BugColor.blue);
    });

    test(
      'same-column merge adjusts target row when source is above target',
      () {
        final board = BoardState([
          [BugColor.blue, BugColor.blue, BugColor.blue],
          [],
          [],
          [],
          [],
          [],
        ]);

        board.mergePieceAt(
          sourceColumn: 0,
          sourceRow: 0,
          targetColumn: 0,
          targetRow: 2,
        );

        expect(board.columns[0], hasLength(2));
        expect(board.pieceAt(0, 0)!.charged, isFalse);
        expect(board.pieceAt(0, 1)!.charged, isTrue);
        expect(board.pieceAt(0, 1)!.color, BugColor.blue);
      },
    );
  });

  test('campaign opens with a focused guided movement tutorial', () {
    final board = tutorialLevels.first.createBoard();
    final pieceCount = board.columns.fold<int>(
      0,
      (total, column) => total + column.length,
    );

    expect(pieceCount, 2);
    expect(tutorialLevels.first.pressureEnabled, isFalse);
    expect(tutorialLevels.first.stuckHelpEnabled, isTrue);
    expect(
      tutorialLevels.first.powerSlots.every((slot) => slot.locked),
      isTrue,
    );
    expect(tutorialLevels.first.tutorialDragSteps, hasLength(3));
    expect(tutorialLevels.first.objective.type, ObjectiveType.moveBug);
    expect(MatchSystem().findDetonations(board), isEmpty);
  });

  test('level design separates required tutorials from map01 challenges', () {
    expect(tutorialLevels, hasLength(PlayerProgress.requiredTutorialLevels));
    expect(tutorialLevels.every((level) => level.stuckHelpEnabled), isTrue);
    expect(map01Levels, hasLength(9));
    expect(map01Levels.every((level) => level.stuckHelpEnabled), isTrue);
    expect(map01Levels.first.id, 'map01_grove_sorting');
    expect(map01Levels.first.name, 'Grove Sorting');
  });

  test('adventure HUD level number follows the active map level', () {
    final game = ChameleonPuzzleGame(
      mode: GameMode.adventure,
      initialLevelSetId: LevelSetId.map01,
    );

    game.levelSetId = LevelSetId.map01;
    game.levelIndex = 3;

    expect(game.displayLevelNumber, 4);
  });

  test('stuck help should add the minimum pair needed for another chance', () {
    final availableColumns = [0, 1, 2, 3, 4, 5];
    final helperColumns = availableColumns.take(
      min(2, availableColumns.length),
    );

    expect(helperColumns, [0, 1]);
    expect(helperColumns, hasLength(2));
  });

  test('required tutorial openings can complete their checklist goals', () {
    final matchSystem = MatchSystem();

    expect(
      ObjectiveProgress.empty
          .registerBugMoved()
          .registerBugMoved()
          .registerBugMoved()
          .isComplete(tutorialLevels[0].objective),
      isTrue,
    );

    final glowBoard = tutorialLevels[1].createBoard();
    glowBoard.mergePieceAt(
      sourceColumn: 1,
      sourceRow: 0,
      targetColumn: 0,
      targetRow: 0,
    );
    expect(matchSystem.findDetonations(glowBoard), isEmpty);
    glowBoard.mergePieceAt(
      sourceColumn: 3,
      sourceRow: 0,
      targetColumn: 2,
      targetRow: 0,
    );
    expect(matchSystem.findDetonations(glowBoard), isEmpty);
    glowBoard.mergePieceAt(
      sourceColumn: 5,
      sourceRow: 0,
      targetColumn: 4,
      targetRow: 0,
    );
    final glowProgress = ObjectiveProgress.empty
        .registerGlowCreated()
        .registerGlowCreated()
        .registerGlowCreated();
    expect(
      tutorialLevels[1].activeObjectives.every(glowProgress.isComplete),
      isTrue,
    );

    final matchBoard = tutorialLevels[2].createBoard();
    matchBoard.mergePieceAt(
      sourceColumn: 2,
      sourceRow: 2,
      targetColumn: 1,
      targetRow: 2,
    );
    expect(matchSystem.findDetonations(matchBoard), isEmpty);
    final movedRed = matchBoard.removePieceAt(3, 2);
    matchBoard.insertPieceBottom(2, movedRed);
    final redGroups = matchSystem.findDetonations(matchBoard);
    final redRemoved = matchBoard.clearCells(
      redGroups.expand((group) => group),
    );

    matchBoard.mergePieceAt(
      sourceColumn: 2,
      sourceRow: 1,
      targetColumn: 1,
      targetRow: 1,
    );
    expect(matchSystem.findDetonations(matchBoard), isEmpty);
    final movedBlue = matchBoard.removePieceAt(3, 1);
    matchBoard.insertPieceBottom(2, movedBlue);
    final blueGroups = matchSystem.findDetonations(matchBoard);
    final blueRemoved = matchBoard.clearCells(
      blueGroups.expand((group) => group),
    );

    matchBoard.mergePieceAt(
      sourceColumn: 2,
      sourceRow: 0,
      targetColumn: 1,
      targetRow: 0,
    );
    expect(matchSystem.findDetonations(matchBoard), isEmpty);
    final movedYellow = matchBoard.removePieceAt(3, 0);
    matchBoard.insertPieceBottom(2, movedYellow);
    final yellowGroups = matchSystem.findDetonations(matchBoard);
    final yellowRemoved = matchBoard.clearCells(
      yellowGroups.expand((group) => group),
    );
    final matchProgress = ObjectiveProgress.empty
        .registerGlowCreated()
        .registerClear(redRemoved, cascadeCount: 1, boardCleared: false)
        .registerGlowCreated()
        .registerClear(blueRemoved, cascadeCount: 1, boardCleared: false)
        .registerGlowCreated()
        .registerClear(yellowRemoved, cascadeCount: 1, boardCleared: true);
    expect(
      tutorialLevels[2].activeObjectives.every(matchProgress.isComplete),
      isTrue,
    );

    final bigBoard = tutorialLevels[4].createBoard();
    final moved = bigBoard.removePieceAt(5, 0);
    bigBoard.insertPieceBottom(1, moved);
    _applyPromotionsForTest(bigBoard, matchSystem);
    bigBoard.mergePieceAt(
      sourceColumn: 4,
      sourceRow: 0,
      targetColumn: 3,
      targetRow: 0,
    );
    expect(matchSystem.findDetonations(bigBoard), isEmpty);
    final glow = bigBoard.removePieceAt(3, 0);
    bigBoard.insertPieceBottom(1, glow);
    final bigGroups = matchSystem.findDetonations(bigBoard);
    final bigRemoved = bigBoard.clearCells(bigGroups.expand((group) => group));
    final bigProgress = ObjectiveProgress.empty
        .registerBugMoved()
        .registerBugMoved()
        .registerGlowCreated()
        .registerClear(bigRemoved, cascadeCount: 1, boardCleared: false);
    expect(
      tutorialLevels[4].activeObjectives.every(bigProgress.isComplete),
      isTrue,
    );

    final dangerBoard = tutorialLevels[5].createBoard();
    dangerBoard.mergePieceAt(
      sourceColumn: 5,
      sourceRow: 0,
      targetColumn: 4,
      targetRow: 0,
    );
    expect(matchSystem.findDetonations(dangerBoard), isEmpty);
    final dangerGlow = dangerBoard.removePieceAt(4, 0);
    expect(dangerGlow.charged, isTrue);
    expect(dangerBoard.isColumnFull(0), isTrue);
    expect(dangerBoard.colorAt(0, 7), BugColor.red);
    dangerBoard.insertPieceBottom(0, dangerGlow);
    dangerBoard.clearCells({const BoardCell(0, 0)});
    final dangerGroups = matchSystem.findDetonations(dangerBoard);
    expect(dangerGroups, hasLength(1));
    expect(dangerGroups.single, {
      const BoardCell(0, 6),
      const BoardCell(0, 7),
      const BoardCell(1, 7),
      const BoardCell(2, 7),
    });
    final dangerRemoved = dangerBoard.clearCells(dangerGroups.single);
    final dangerProgress = ObjectiveProgress.empty
        .registerGlowCreated()
        .registerDanger(1)
        .registerClear(dangerRemoved, cascadeCount: 1, boardCleared: false);
    expect(
      tutorialLevels[5].activeObjectives.every(dangerProgress.isComplete),
      isTrue,
    );
  });

  test('map01 does not use power ups', () {
    for (final level in map01Levels) {
      expect(level.powerSlots.every((slot) => slot.locked), isTrue);
      expect(level.powerSlots.every((slot) => slot.type == null), isTrue);
    }
  });

  test('map01 smoke validates board openings and intentional BIG setups', () {
    final matchSystem = MatchSystem();
    const bigSetupLevelIndexes = {3, 5, 6, 7, 8};

    for (var index = 0; index < map01Levels.length; index += 1) {
      final board = map01Levels[index].createBoard();
      final detonations = matchSystem.findDetonations(board);
      final promotions = matchSystem.findBigPromotions(board);

      expect(detonations, isEmpty, reason: 'Map01-${index + 1}');
      expect(
        promotions.isNotEmpty,
        bigSetupLevelIndexes.contains(index),
        reason: 'Map01-${index + 1} BIG setup should match the level plan.',
      );
      expect(
        board.hasGlowMergeMove(),
        isTrue,
        reason: 'Map01-${index + 1} should open with more than a dead board.',
      );
      expect(
        map01Levels[index].stuckHelpEnabled,
        isTrue,
        reason: 'Map01-${index + 1} needs helper bugs as a soft-lock escape.',
      );
    }
  });

  test('chain tutorial clears red then cascades into blue and yellow', () {
    final board = tutorialLevels[3].createBoard();
    final matchSystem = MatchSystem();

    expect(tutorialLevels[3].name, 'Chain Drop');
    expect(tutorialLevels[3].pressureEnabled, isFalse);
    expect(tutorialLevels[3].powerSlots.every((slot) => slot.locked), isTrue);

    board.mergePieceAt(
      sourceColumn: 5,
      sourceRow: 0,
      targetColumn: 1,
      targetRow: 0,
    );

    expect(matchSystem.findDetonations(board), isEmpty);

    board.mergePieceAt(
      sourceColumn: 4,
      sourceRow: 0,
      targetColumn: 0,
      targetRow: 4,
    );

    expect(matchSystem.findDetonations(board), isEmpty);

    board.mergePieceAt(
      sourceColumn: 3,
      sourceRow: 0,
      targetColumn: 2,
      targetRow: 2,
    );

    final redGroups = matchSystem.findDetonations(board);

    expect(redGroups, hasLength(1));
    expect(redGroups.single, {
      const BoardCell(0, 2),
      const BoardCell(1, 2),
      const BoardCell(2, 2),
    });

    board.clearCells(redGroups.single);

    final blueGroups = matchSystem.findDetonations(board);

    expect(blueGroups, hasLength(1));
    expect(blueGroups.single, {
      const BoardCell(0, 1),
      const BoardCell(0, 2),
      const BoardCell(0, 3),
    });

    board.clearCells(blueGroups.single);

    final yellowGroups = matchSystem.findDetonations(board);

    expect(yellowGroups, hasLength(1));
    expect(yellowGroups.single, {
      const BoardCell(0, 0),
      const BoardCell(0, 1),
      const BoardCell(1, 0),
    });
  });

  group('PressureRowGenerator', () {
    test('early pressure rows do not immediately promote top pairs', () {
      final board = BoardState([
        [BugColor.orange],
        [BugColor.orange],
        [],
        [],
        [],
        [],
      ]);
      final generator = PressureRowGenerator(random: Random(12));
      final matchSystem = MatchSystem();

      for (var i = 0; i < 30; i += 1) {
        final copy = board.copy();
        copy.insertTopRow(generator.spawnRow(board: board, arcadeLevel: 1));

        expect(matchSystem.findBigPromotions(copy), isEmpty);
      }
    });

    test('pressure rows stop adding BIG setups when a level is at its cap', () {
      final board = BoardState([
        [BugColor.red, BugColor.red],
        [BugColor.red, BugColor.red],
        [BugColor.yellow, BugColor.yellow],
        [BugColor.yellow, BugColor.yellow],
        [BugColor.blue],
        [BugColor.blue],
      ]);
      board
        ..promoteBigBlock(column: 0, row: 0, bigId: 1)
        ..promoteBigBlock(column: 2, row: 0, bigId: 2);
      final generator = PressureRowGenerator(random: Random(34));
      final matchSystem = MatchSystem();

      for (var i = 0; i < 30; i += 1) {
        final copy = board.copy();
        copy.insertTopRow(generator.spawnRow(board: board, arcadeLevel: 3));

        expect(matchSystem.findBigPromotions(copy), isEmpty);
      }
    });

    test(
      'pressure rows feed normal colors that can answer existing BIG bugs',
      () {
        final board = BoardState([
          [BugColor.orange, BugColor.orange],
          [BugColor.orange, BugColor.orange],
          [BugColor.red],
          [BugColor.blue],
          [BugColor.yellow],
          [BugColor.purple],
        ]);
        board.promoteBigBlock(column: 0, row: 0, bigId: 1);
        final generator = PressureRowGenerator(random: Random(56));
        var rowsWithOrange = 0;

        for (var i = 0; i < 20; i += 1) {
          final row = generator.spawnRow(board: board, arcadeLevel: 5);
          if (row.any((piece) => piece.color == BugColor.orange)) {
            rowsWithOrange += 1;
          }
        }

        expect(rowsWithOrange, greaterThanOrEqualTo(16));
      },
    );
  });

  group('PowerUpSystem', () {
    test('Berry targets a small bug and clears safe cells in that column', () {
      final board = BoardState([
        [BugColor.red, BugColor.blue, BugColor.yellow],
        [],
        [],
        [],
        [],
        [],
      ]);

      final cells = PowerUpSystem().berryCells(board, const BoardCell(0, 1));

      expect(cells, {
        const BoardCell(0, 0),
        const BoardCell(0, 1),
        const BoardCell(0, 2),
      });
    });

    test('Bloom recolors non-BIG pieces in the selected row', () {
      final board = BoardState([
        [BugColor.red, BugColor.blue],
        [BugColor.yellow, BugColor.orange],
        [BugColor.purple],
        [],
        [],
        [],
      ]);

      final changes = PowerUpSystem().bloomChanges(
        board,
        const BoardCell(0, 1),
      );

      expect(changes[const BoardCell(1, 1)]!.color, BugColor.blue);
      expect(changes.containsKey(const BoardCell(0, 1)), isFalse);
      expect(changes.containsKey(const BoardCell(2, 1)), isFalse);
    });

    test('Pollen clears a 3x3 area around the target cell', () {
      final board = BoardState([
        [BugColor.red, BugColor.blue, BugColor.yellow],
        [BugColor.red, BugColor.blue, BugColor.yellow],
        [BugColor.red, BugColor.blue, BugColor.yellow],
        [],
        [],
        [],
      ]);

      final cells = PowerUpSystem().pollenCells(board, const BoardCell(1, 1));

      expect(cells, hasLength(9));
      expect(cells, contains(const BoardCell(0, 0)));
      expect(cells, contains(const BoardCell(2, 2)));
    });

    test('Water clears small bugs matching the selected color', () {
      final board = BoardState([
        [BugColor.red, BugColor.blue],
        [BugColor.red],
        [BugColor.yellow, BugColor.red],
        [],
        [],
        [],
      ]);

      final cells = PowerUpSystem().waterCells(board, const BoardCell(0, 0));

      expect(cells, {
        const BoardCell(0, 0),
        const BoardCell(1, 0),
        const BoardCell(2, 1),
      });
    });

    test('Firefly removes about half of small bugs and ignores BIG bugs', () {
      final board = BoardState([
        [BugColor.orange, BugColor.orange],
        [BugColor.orange, BugColor.orange],
        [BugColor.red],
        [BugColor.blue],
        [BugColor.yellow],
        [BugColor.purple],
      ]);
      board.promoteBigBlock(column: 0, row: 0, bigId: 1);

      final cells = PowerUpSystem(random: Random(7)).fireflyCells(board);

      expect(cells, hasLength(2));
      expect(cells, isNot(contains(const BoardCell(0, 0))));
      expect(cells, isNot(contains(const BoardCell(1, 1))));
    });

    test(
      'power clears preserve BIG bugs by skipping risky cells above them',
      () {
        final board = BoardState([
          [BugColor.red, BugColor.orange, BugColor.orange],
          [BugColor.blue, BugColor.orange, BugColor.orange],
          [],
          [],
          [],
          [],
        ]);
        board.promoteBigBlock(column: 0, row: 1, bigId: 1);

        final cells = PowerUpSystem().berryCells(board, const BoardCell(0, 0));

        expect(cells, isEmpty);
      },
    );
  });

  group('ObjectiveProgress', () {
    test('counts cleared ladybug value by total and color', () {
      final progress = ObjectiveProgress.empty.registerClear(
        [
          const BoardPiece(BugColor.blue),
          const BoardPiece(BugColor.blue, charged: true),
          const BoardPiece(
            BugColor.orange,
            type: BoardPieceType.bigAnchor,
            bigId: 1,
          ),
          const BoardPiece(
            BugColor.orange,
            type: BoardPieceType.bigPart,
            bigId: 1,
          ),
        ],
        cascadeCount: 2,
        boardCleared: false,
      );

      expect(progress.valueFor(Objective.clearTotal(11)), 11);
      expect(progress.valueFor(Objective.clearColor(BugColor.blue, 3)), 3);
      expect(progress.valueFor(Objective.clearColor(BugColor.orange, 8)), 8);
      expect(progress.valueFor(Objective.clearBig(1)), 1);
      expect(progress.valueFor(Objective.reachCascade(2)), 2);
      expect(progress.isComplete(Objective.clearColor(BugColor.blue, 3)), true);
    });

    test('tracks movement, glow, split, and survival objectives', () {
      final progress = ObjectiveProgress.empty
          .registerBugMoved()
          .registerGlowCreated()
          .registerDanger(1)
          .registerSurvival(12.6)
          .registerClear(
            const <BoardPiece>[],
            cascadeCount: 1,
            boardCleared: false,
            bigSplitCount: 1,
          );

      expect(progress.isComplete(Objective.moveBug(1)), isTrue);
      expect(progress.isComplete(Objective.makeGlow(1)), isTrue);
      expect(progress.isComplete(Objective.splitBig(1)), isTrue);
      expect(progress.isComplete(Objective.reachDanger(1)), isTrue);
      expect(progress.valueFor(Objective.surviveSeconds(20)), 12);
    });

    test('tracks clear-all completion', () {
      final progress = ObjectiveProgress.empty.registerClear(
        [const BoardPiece(BugColor.red)],
        cascadeCount: 1,
        boardCleared: true,
      );

      expect(progress.isComplete(Objective.clearAll()), true);
    });
  });

  test('game saves preserve mode and objective progress', () {
    final progress = ObjectiveProgress.empty.registerClear(
      [const BoardPiece(BugColor.red, charged: true)],
      cascadeCount: 1,
      boardCleared: false,
    );
    final save = GameSave(
      levelSetId: LevelSetId.map01,
      levelIndex: 1,
      mode: GameMode.adventure,
      columns: List<List<BoardPiece>>.generate(
        BoardState.columnCount,
        (_) => <BoardPiece>[],
      ),
      chameleon: ChameleonState(columnIndex: 0),
      score: 75,
      highestCascade: 1,
      currentArcadeLevel: 2,
      nextLevelScore: 180,
      combo: 1,
      comboRemaining: 1.5,
      danger: 0,
      powerCounts: const {PowerUpType.berry: 1},
      objectiveProgress: progress,
      timeRemaining: 120,
      refillTimer: 8,
      facingRight: true,
      nextBigBugId: 3,
    );

    final decoded = GameSave.decode(save.encode());

    expect(decoded, isNotNull);
    expect(decoded!.mode, GameMode.adventure);
    expect(decoded.levelSetId, LevelSetId.map01);
    expect(decoded.objectiveProgress.valueFor(Objective.clearTotal(2)), 2);
    expect(
      decoded.objectiveProgress.valueFor(Objective.clearColor(BugColor.red, 2)),
      2,
    );
  });

  test('legacy global save indices migrate to level sets', () {
    final columns = List<List<Object>>.generate(
      BoardState.columnCount,
      (_) => <Object>[],
    );
    final encoded = jsonEncode({
      'version': 1,
      'levelIndex': 8,
      'mode': 'adventure',
      'columns': columns,
      'chameleon': {
        'columnIndex': 0,
        'heldColor': null,
        'heldCharged': false,
        'swallowedCount': 0,
      },
      'score': 0,
      'highestCascade': 0,
      'currentArcadeLevel': 1,
      'nextLevelScore': 560,
      'combo': 0,
      'comboRemaining': 0,
      'danger': 0,
      'powerCounts': {},
      'objectiveProgress': ObjectiveProgress.empty.toJson(),
      'timeRemaining': 120,
      'refillTimer': 8,
      'facingRight': false,
      'nextBigBugId': 1,
    });

    final decoded = GameSave.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.levelSetId, LevelSetId.map01);
    expect(decoded.levelIndex, 2);
  });
}

void _applyPromotionsForTest(BoardState board, MatchSystem matchSystem) {
  for (final promotion in matchSystem.findBigPromotions(board)) {
    board.promoteBigBlock(
      column: promotion.column,
      row: promotion.row,
      bigId: promotion.column + 1,
    );
  }
}
