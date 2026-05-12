import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:chameleon_puzzle_demo/game/levels/demo_levels.dart';
import 'package:chameleon_puzzle_demo/game/models/board_cell.dart';
import 'package:chameleon_puzzle_demo/game/models/board_piece.dart';
import 'package:chameleon_puzzle_demo/game/models/board_state.dart';
import 'package:chameleon_puzzle_demo/game/models/bug_color.dart';
import 'package:chameleon_puzzle_demo/game/models/chameleon_state.dart';
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

    test('glowing bug clears the full connected same-color group', () {
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

    test('clearing above one side removes the whole BIG bug safely', () {
      final board = BoardState([
        [BugColor.blue, BugColor.orange, BugColor.orange],
        [BugColor.yellow, BugColor.orange, BugColor.orange],
        [],
        [],
        [],
      ]);
      board.promoteBigBlock(column: 0, row: 1, bigId: 1);

      final removed = board.clearCells({const BoardCell(0, 0)});

      expect(removed.map((piece) => piece.bigId).whereType<int>().toSet(), {1});
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

  test('campaign opens with a focused no-pressure drag tutorial', () {
    final board = demoLevels.first.createBoard();
    final pieceCount = board.columns.fold<int>(
      0,
      (total, column) => total + column.length,
    );

    expect(pieceCount, lessThanOrEqualTo(8));
    expect(demoLevels.first.pressureEnabled, isFalse);
    expect(demoLevels.first.powerSlots.every((slot) => slot.locked), isTrue);
    expect(MatchSystem().findDetonations(board), isEmpty);
  });

  test('campaign unlocks power slots through tutorial progression', () {
    expect(demoLevels[2].powerSlots.first.type, PowerUpType.berry);
    expect(demoLevels[2].powerSlots.first.count, 1);
    expect(demoLevels[2].powerSlots[1].locked, isTrue);

    expect(demoLevels[6].powerSlots[0].type, PowerUpType.berry);
    expect(demoLevels[6].powerSlots[1].type, PowerUpType.bloom);
    expect(demoLevels[6].powerSlots[2].locked, isTrue);

    expect(demoLevels[9].powerSlots[2].type, PowerUpType.water);
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
}
