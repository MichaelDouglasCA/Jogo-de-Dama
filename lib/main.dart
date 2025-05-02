// Autor: Michael Douglas
// GitHub: https://github.com/MichaelDouglasCA
// Descrição: Implementação de um jogo de damas usando o framework Flame.
// Este arquivo contém a lógica do jogo, interface gráfica e IA para partidas contra o computador.

import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Classe que representa um movimento no jogo de damas.
class Move {
  final Offset from; // Posição inicial da peça.
  final Offset to; // Posição final da peça.
  final bool isCapture; // Indica se o movimento é uma captura.
  final List<Offset> capturedPieces; // Lista de posições das peças capturadas.

  Move(
    this.from,
    this.to, {
    this.isCapture = false,
    this.capturedPieces = const [],
  });
}

// Classe principal do jogo, que estende FlameGame para gerenciar o estado e a renderização.
class MyGame extends FlameGame {
  static const int boardSize = 8; // Tamanho do tabuleiro (8x8).
  double tileSize = 80.0; // Tamanho de cada casa do tabuleiro em pixels.
  // Representação do tabuleiro como uma matriz 8x8.
  // 0: casa vazia, 1: peça do jogador 1, 2: peça do jogador 2, 3: dama do jogador 1, 4: dama do jogador 2.
  List<List<int>> board = List.generate(
    boardSize,
    (i) => List.filled(boardSize, 0),
  );
  int currentPlayer = 1; // Jogador atual (1 ou 2).
  Offset? selectedPiece; // Posição da peça selecionada.
  List<Move> validMoves = []; // Lista de movimentos válidos para a peça selecionada.
  bool gameOver = false; // Indica se o jogo terminou.
  String winner = ''; // Nome do vencedor.
  Offset? movingPiece; // Posição da peça em animação.
  Offset? targetPosition; // Posição alvo da peça em animação.
  double animationProgress = 0.0; // Progresso da animação de movimento (0.0 a 1.0).
  bool isAnimating = false; // Indica se uma animação está em andamento.
  bool isPlayerVsAI = false; // Modo de jogo (true para jogador vs IA).
  bool isAITurn = false; // Indica se é o turno da IA.
  bool isAIThinking = false; // Indica se a IA está processando um movimento.
  int player1Score = 0; // Pontuação do jogador 1.
  int player2Score = 0; // Pontuação do jogador 2.
  List<String> matchHistory = []; // Histórico de resultados das partidas.
  int player1Pieces = 12; // Número de peças restantes do jogador 1.
  int player2Pieces = 12; // Número de peças restantes do jogador 2.
  int player1Captured = 0; // Peças capturadas pelo jogador 2.
  int player2Captured = 0; // Peças capturadas pelo jogador 1.
  String aiDifficulty = 'normal'; // Nível de dificuldade da IA ('easy', 'normal', 'hard').
  bool gameStarted = false; // Indica se o jogo foi iniciado.
  bool hasUserInteracted = false; // Verifica se o usuário interagiu para iniciar a música.

  double offsetX = 0; // Deslocamento horizontal do tabuleiro.
  double offsetY = 0; // Deslocamento vertical do tabuleiro.

  // Constantes para avaliação do tabuleiro pela IA.
  static const int PIECE_VALUE = 10; // Valor de uma peça comum.
  static const int KING_VALUE = 30; // Valor de uma dama.
  static const int POSITION_BONUS = 2; // Bônus por posição avançada.
  static const int CAPTURE_BONUS = 50; // Bônus por captura.
  static const int CENTER_CONTROL_BONUS = 5; // Bônus por controle do centro.
  static const int PROTECTED_PIECE_BONUS = 3; // Bônus por peça protegida.

  // Método chamado quando o jogo é carregado.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    initializeBoard(); // Inicializa o tabuleiro.
    // Carrega os arquivos de áudio.
    try {
      await FlameAudio.audioCache.loadAll([
        'move.mp3',
        'capture.mp3',
        'promote.mp3',
        'win.mp3',
        'background_music.mp3',
      ]);
      print('Áudios carregados com sucesso.');
    } catch (e) {
      print('Erro ao carregar áudios: $e');
    }
    calculateOffsets(); // Calcula os deslocamentos do tabuleiro.
    overlays.add('MainMenu'); // Exibe o menu principal.
    print('Jogo carregado, Player 1 começa (música ainda não iniciada).');
  }

  // Inicia a música de fundo após a primeira interação do usuário.
  void startBackgroundMusic() {
    if (!hasUserInteracted) {
      try {
        FlameAudio.bgm.play('background_music.mp3', volume: 0.1);
        hasUserInteracted = true;
        print('Música de fundo iniciada após interação do usuário.');
      } catch (e) {
        print('Erro ao iniciar música de fundo: $e');
      }
    }
  }

  // Calcula os deslocamentos para centralizar o tabuleiro na tela.
  void calculateOffsets() {
    double boardWidth = boardSize * tileSize;
    double boardHeight = boardSize * tileSize;
    offsetX = (size.x - boardWidth - 300) / 2 + 150;
    offsetY = (size.y - boardHeight) / 2;
  }

  // Inicializa o tabuleiro com as peças nas posições iniciais.
  void initializeBoard() {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if ((i + j) % 2 == 1) { // Apenas casas escuras.
          if (i < 3) {
            board[i][j] = isPlayerVsAI ? 2 : 1; // Peças do jogador 2 ou IA.
          } else if (i > 4) {
            board[i][j] = isPlayerVsAI ? 1 : 2; // Peças do jogador 1.
          }
        }
      }
    }
    player1Pieces = 12;
    player2Pieces = 12;
    player1Captured = 0;
    player2Captured = 0;
    currentPlayer = 1;
    gameStarted = false;
    print('Tabuleiro inicializado, turno do Player 1');
  }

  // Reinicia o jogo, restaurando o estado inicial.
  void resetGame() {
    board = List.generate(boardSize, (i) => List.filled(boardSize, 0));
    currentPlayer = 1;
    selectedPiece = null;
    validMoves.clear();
    gameOver = false;
    winner = '';
    movingPiece = null;
    targetPosition = null;
    animationProgress = 0.0;
    isAnimating = false;
    isAITurn = false;
    isAIThinking = false;
    gameStarted = false;
    initializeBoard();
    print('Jogo resetado, Player 1 começa');
  }

  // Ajusta o tamanho do tabuleiro quando a janela é redimensionada.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!overlays.isActive('MainMenu') &&
        !overlays.isActive('History') &&
        !overlays.isActive('DifficultyMenu') &&
        !overlays.isActive('About')) {
      tileSize = min(size.x - 560, size.y) / boardSize;
      offsetX = (size.x - tileSize * boardSize - 300) / 2 + 150;
      offsetY = (size.y - tileSize * boardSize) / 2;
    } else {
      tileSize = 80.0;
      calculateOffsets();
    }
  }

  // Renderiza os elementos visuais do jogo.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!overlays.isActive('MainMenu') &&
        !overlays.isActive('History') &&
        !overlays.isActive('DifficultyMenu') &&
        !overlays.isActive('About')) {
      drawBoard(canvas); // Desenha o tabuleiro.
      drawPieces(canvas); // Desenha as peças.
      drawValidMoves(canvas); // Desenha os movimentos válidos.
      if (gameOver) drawGameOver(canvas); // Exibe a tela de fim de jogo.
      drawScoreboard(canvas); // Desenha o placar.
      drawPlayerTurnIndicator(canvas); // Indica o turno atual.
      if (isAIThinking) drawAIThinking(canvas); // Mostra que a IA está pensando.
    }
  }

  // Desenha o tabuleiro com casas claras e escuras.
  void drawBoard(Canvas canvas) {
    final paint = Paint();
    final borderPaint = Paint()
      ..color = Colors.yellow[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        paint.color = (i + j) % 2 == 0 ? Colors.brown[200]! : Colors.brown[400]!;
        canvas.drawRect(
          Rect.fromLTWH(
            offsetX + j * tileSize,
            offsetY + i * tileSize,
            tileSize,
            tileSize,
          ),
          paint,
        );
      }
    }
    // Desenha a borda do tabuleiro.
    canvas.drawRect(
      Rect.fromLTWH(
        offsetX,
        offsetY,
        tileSize * boardSize,
        tileSize * boardSize,
      ),
      borderPaint,
    );
  }

  // Desenha as peças no tabuleiro, incluindo animações de movimento.
  void drawPieces(Canvas canvas) {
    final paint = Paint();
    final borderPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != 0) {
          bool isCurrentPlayerPiece =
              (board[i][j] == currentPlayer || board[i][j] == currentPlayer + 2);
          paint.color = (board[i][j] == 1 || board[i][j] == 3)
              ? Colors.red
              : Colors.black;
          canvas.drawCircle(
            Offset(
              offsetX + j * tileSize + tileSize / 2,
              offsetY + i * tileSize + tileSize / 2,
            ),
            tileSize / 2.5,
            paint,
          );
          if (board[i][j] == 3 || board[i][j] == 4) { // Desenha o centro da dama.
            paint.color = Colors.yellow;
            canvas.drawCircle(
              Offset(
                offsetX + j * tileSize + tileSize / 2,
                offsetY + i * tileSize + tileSize / 2,
              ),
              tileSize / 4,
              paint,
            );
          }
          if (isCurrentPlayerPiece) { // Destaca a peça do jogador atual.
            canvas.drawCircle(
              Offset(
                offsetX + j * tileSize + tileSize / 2,
                offsetY + i * tileSize + tileSize / 2,
              ),
              tileSize / 2.5 + 1.5,
              borderPaint,
            );
          }
        }
      }
    }
    // Desenha a peça em movimento durante a animação.
    if (isAnimating && movingPiece != null && targetPosition != null) {
      final currentX =
          movingPiece!.dx + (targetPosition!.dx - movingPiece!.dx) * animationProgress;
      final currentY =
          movingPiece!.dy + (targetPosition!.dy - movingPiece!.dy) * animationProgress;
      paint.color =
          board[targetPosition!.dy.toInt()][targetPosition!.dx.toInt()] == 1
              ? Colors.red
              : Colors.black;
      canvas.drawCircle(
        Offset(
          offsetX + currentX * tileSize + tileSize / 2,
          offsetY + currentY * tileSize + tileSize / 2,
        ),
        tileSize / 2.5,
        paint,
      );
      canvas.drawCircle(
        Offset(
          offsetX + currentX * tileSize + tileSize / 2,
          offsetY + currentY * tileSize + tileSize / 2,
        ),
        tileSize / 2.5 + 1.5,
        borderPaint,
      );
    }
  }

  // Desenha indicadores visuais para movimentos válidos.
  void drawValidMoves(Canvas canvas) {
    final paint = Paint()..color = Colors.blue.withOpacity(0.5);
    for (var move in validMoves) {
      canvas.drawCircle(
        Offset(
          offsetX + move.to.dx * tileSize + tileSize / 2,
          offsetY + move.to.dy * tileSize + tileSize / 2,
        ),
        tileSize / 5,
        paint,
      );
    }
  }

  // Exibe a mensagem de fim de jogo com o vencedor.
  void drawGameOver(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Game Over!\n$winner wins!',
        style: TextStyle(color: Colors.white, fontSize: 32),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        size.y / 2 - textPainter.height / 2,
      ),
    );
  }

  // Desenha o placar com informações dos jogadores.
  void drawScoreboard(Canvas canvas) {
    final scoreboardX = offsetX + tileSize * boardSize + 20;
    final scoreboardWidth = 260;
    final scoreboardHeight = tileSize * boardSize + 60;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.brown[900]!, Colors.brown[600]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, 0, scoreboardWidth as double, scoreboardHeight),
      );
    final borderPaint = Paint()
      ..color = Colors.yellow[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    // Desenha o fundo do placar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scoreboardX,
          offsetY - 30,
          scoreboardWidth as double,
          scoreboardHeight,
        ),
        Radius.circular(25),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scoreboardX,
          offsetY - 30,
          scoreboardWidth as double,
          scoreboardHeight,
        ),
        Radius.circular(25),
      ),
      borderPaint,
    );

    // Título do placar.
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'Placar',
        style: TextStyle(
          color: Colors.yellow[600],
          fontSize: 30,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - titlePainter.width / 2,
        offsetY + 30,
      ),
    );

    // Placar do jogador 1.
    final player1BoxPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.red[900]!, Colors.red[700]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, scoreboardWidth - 40, 200));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scoreboardX + 20,
          offsetY + 80,
          scoreboardWidth - 40,
          200,
        ),
        Radius.circular(20),
      ),
      player1BoxPaint,
    );
    final player1TitlePainter = TextPainter(
      text: TextSpan(
        text: isPlayerVsAI ? 'Jogador (Pretas)' : 'Jogador 1',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    player1TitlePainter.layout();
    player1TitlePainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - player1TitlePainter.width / 2,
        offsetY + 100,
      ),
    );

    final player1StatsPainter = TextPainter(
      text: TextSpan(
        text: 'Pontos: $player1Score\nPeças Restantes: $player1Pieces',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    player1StatsPainter.layout();
    player1StatsPainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - player1StatsPainter.width / 2,
        offsetY + 130,
      ),
    );

    // Peças capturadas do jogador 2.
    final piecePaintPlayer1 = Paint()..color = Colors.black;
    for (int i = 0; i < player2Captured; i++) {
      int row = i ~/ 6;
      int col = i % 6;
      canvas.drawCircle(
        Offset(scoreboardX + 40 + col * 35, offsetY + 200 + row * 35),
        12,
        piecePaintPlayer1,
      );
    }
    for (int i = player2Captured; i < 12; i++) {
      int row = i ~/ 6;
      int col = i % 6;
      canvas.drawCircle(
        Offset(scoreboardX + 40 + col * 35, offsetY + 200 + row * 35),
        12,
        Paint()..color = Colors.black.withOpacity(0.2),
      );
    }

    // Placar do jogador 2.
    final player2BoxPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey[900]!, Colors.grey[700]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, scoreboardWidth - 40, 200));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scoreboardX + 20,
          offsetY + 350,
          scoreboardWidth - 40,
          200,
        ),
        Radius.circular(20),
      ),
      player2BoxPaint,
    );
    final player2TitlePainter = TextPainter(
      text: TextSpan(
        text: isPlayerVsAI ? 'IA (Vermelhas)' : 'Jogador 2',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    player2TitlePainter.layout();
    player2TitlePainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - player2TitlePainter.width / 2,
        offsetY + 370,
      ),
    );

    final player2StatsPainter = TextPainter(
      text: TextSpan(
        text: 'Pontos: $player2Score\nPeças Restantes: $player2Pieces',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    player2StatsPainter.layout();
    player2StatsPainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - player2StatsPainter.width / 2,
        offsetY + 400,
      ),
    );

    // Peças capturadas do jogador 1.
    final piecePaintPlayer2 = Paint()..color = Colors.red;
    for (int i = 0; i < player1Captured; i++) {
      int row = i ~/ 6;
      int col = i % 6;
      canvas.drawCircle(
        Offset(scoreboardX + 40 + col * 35, offsetY + 470 + row * 35),
        12,
        piecePaintPlayer2,
      );
    }
    for (int i = player1Captured; i < 12; i++) {
      int row = i ~/ 6;
      int col = i % 6;
      canvas.drawCircle(
        Offset(scoreboardX + 40 + col * 35, offsetY + 470 + row * 35),
        12,
        Paint()..color = Colors.red.withOpacity(0.2),
      );
    }

    // Botão "Voltar ao Menu".
    final buttonPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.red[900]!, Colors.red[600]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, scoreboardWidth - 40, 50));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scoreboardX + 20,
          offsetY + scoreboardHeight - 120,
          scoreboardWidth - 40,
          50,
        ),
        Radius.circular(10),
      ),
      buttonPaint,
    );
    final buttonTextPainter = TextPainter(
      text: TextSpan(
        text: 'Voltar ao Menu',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    buttonTextPainter.layout();
    buttonTextPainter.paint(
      canvas,
      Offset(
        scoreboardX + scoreboardWidth / 2 - buttonTextPainter.width / 2,
        offsetY + scoreboardHeight - 105,
      ),
    );
  }

  // Desenha o indicador do turno atual.
  void drawPlayerTurnIndicator(Canvas canvas) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: currentPlayer == 1
            ? [Colors.red[900]!, Colors.red[600]!]
            : [Colors.black, Colors.grey[800]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, 240, 100));
    final borderPaint = Paint()
      ..color = Colors.yellow[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: isPlayerVsAI
            ? (currentPlayer == 1 ? 'Vez do Jogador\n(Vermelhas)' : 'Vez da IA\n(Pretas)')
            : 'Vez do Jogador $currentPlayer',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 6),
            Shadow(
              color: Colors.yellow[300]!,
              offset: Offset(0, 0),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final width = max(textPainter.width + 20, 240.0);
    final height = textPainter.height + 20;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offsetX - width - 120,
          offsetY + tileSize * boardSize / 2 - height / 2,
          width,
          height,
        ),
        Radius.circular(15),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offsetX - width - 120,
          offsetY + tileSize * boardSize / 2 - height / 2,
          width,
          height,
        ),
        Radius.circular(15),
      ),
      borderPaint,
    );
    textPainter.paint(
      canvas,
      Offset(
        offsetX - width - 10 - textPainter.width / 2,
        offsetY + tileSize * boardSize / 2 - textPainter.height / 2,
      ),
    );
  }

  // Exibe a mensagem "IA Pensando..." durante o turno da IA.
  void drawAIThinking(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'IA Pensando...',
        style: TextStyle(color: Colors.yellow, fontSize: 24),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.x / 2 - textPainter.width / 2, size.y / 2),
    );
  }

  // Atualiza o estado do jogo a cada frame.
  @override
  void update(double dt) {
    super.update(dt);
    if (isAnimating) {
      animationProgress += dt * 4; // Avança a animação.
      if (animationProgress >= 1.0) {
        animationProgress = 0.0;
        isAnimating = false;
        completeMove(); // Finaliza o movimento.
        print('Animação concluída, turno do Player $currentPlayer');
      }
    }

    // Inicia o turno da IA, se aplicável.
    if (isPlayerVsAI &&
        currentPlayer == 2 &&
        !isAnimating &&
        !gameOver &&
        !isAITurn &&
        !isAIThinking &&
        gameStarted) {
      isAITurn = true;
      print('Turno da IA iniciado');
      _makeAIMoveAsync();
    }

    // Verifica se há um vencedor.
    if (!gameOver) checkForWin();
  }

  // Gerencia os eventos de toque na tela.
  void onTapDown(TapDownDetails details) {
    if (!hasUserInteracted) {
      startBackgroundMusic(); // Inicia a música na primeira interação.
    }

    // Ignora toques se um overlay está ativo.
    if (overlays.isActive('MainMenu') ||
        overlays.isActive('History') ||
        overlays.isActive('DifficultyMenu') ||
        overlays.isActive('About')) {
      if (overlays.isActive('History')) {
        overlays.remove('History');
        overlays.add('MainMenu');
      } else if (overlays.isActive('About')) {
        overlays.remove('About');
        overlays.add('MainMenu');
      }
      return;
    }

    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    // Verifica se o toque foi no botão "Voltar ao Menu".
    final scoreboardX = offsetX + tileSize * boardSize + 20;
    if (x > scoreboardX + 20 &&
        x < scoreboardX + 240 &&
        y > offsetY + tileSize * boardSize - 50 &&
        y < offsetY + tileSize * boardSize) {
      overlays.add('MainMenu');
      print('Voltando ao menu');
      return;
    }

    // Ignora toques durante estados inválidos.
    if (gameOver ||
        isAnimating ||
        (isPlayerVsAI && currentPlayer == 2 && !gameStarted)) {
      print(
        'Toque ignorado: gameOver=$gameOver, isAnimating=$isAnimating, IA turn=$isAITurn, gameStarted=$gameStarted',
      );
      return;
    }

    // Converte as coordenadas do toque em índices do tabuleiro.
    final boardX = ((x - offsetX) / tileSize).floor();
    final boardY = ((y - offsetY) / tileSize).floor();

    if (boardX < 0 ||
        boardX >= boardSize ||
        boardY < 0 ||
        boardY >= boardSize) {
      print('Toque fora do tabuleiro: ($boardX, $boardY)');
      return;
    }

    print('Toque em ($boardX, $boardY) pelo Player $currentPlayer');

    // Seleciona uma peça ou executa um movimento.
    if (selectedPiece == null) {
      if (board[boardY][boardX] == currentPlayer ||
          board[boardY][boardX] == currentPlayer + 2) {
        selectedPiece = Offset(boardX.toDouble(), boardY.toDouble());
        calculateValidMoves(boardX, boardY);
      }
    } else {
      Move? selectedMove = validMoves.firstWhere(
        (move) => move.to.dx.toInt() == boardX && move.to.dy.toInt() == boardY,
        orElse: () => Move(Offset(0, 0), Offset(0, 0)),
      );
      if (selectedMove.to != Offset(0, 0)) {
        startAnimation(
          selectedPiece!.dx.toInt(),
          selectedPiece!.dy.toInt(),
          boardX,
          boardY,
        );
        gameStarted = true;
      } else {
        selectedPiece = null;
        validMoves.clear();
      }
    }
  }

  // Inicia a animação de movimento de uma peça.
  void startAnimation(int fromX, int fromY, int toX, int toY) {
    movingPiece = Offset(fromX.toDouble(), fromY.toDouble());
    targetPosition = Offset(toX.toDouble(), toY.toDouble());
    animationProgress = 0.0;
    isAnimating = true;
    print('Animação iniciada de ($fromX, $fromY) para ($toX, $toY)');
  }

  // Finaliza um movimento após a animação.
  void completeMove() {
    if (movingPiece == null || targetPosition == null) return;

    final fromX = movingPiece!.dx.toInt();
    final fromY = movingPiece!.dy.toInt();
    final toX = targetPosition!.dx.toInt();
    final toY = targetPosition!.dy.toInt();

    Move move = validMoves.firstWhere(
      (m) =>
          m.from == Offset(fromX.toDouble(), fromY.toDouble()) &&
          m.to == Offset(toX.toDouble(), toY.toDouble()),
      orElse: () => Move(
            Offset(fromX.toDouble(), fromY.toDouble()),
            Offset(toX.toDouble(), toY.toDouble()),
          ),
    );

    // Move a peça no tabuleiro.
    board[toY][toX] = board[fromY][fromX];
    board[fromY][fromX] = 0;

    // Processa capturas, se houver.
    if (move.isCapture && move.capturedPieces.isNotEmpty) {
      for (var captured in move.capturedPieces) {
        int midX = captured.dx.toInt();
        int midY = captured.dy.toInt();
        if (board[midY][midX] != 0) {
          board[midY][midX] = 0;
          if (currentPlayer == 1) {
            player2Pieces--;
            player2Captured++;
          } else {
            player1Pieces--;
            player1Captured++;
          }
          try {
            FlameAudio.play('capture.mp3');
          } catch (e) {
            print('Erro ao reproduzir capture.mp3: $e');
          }
          addParticleEffect(midX, midY);
        }
      }
      // Verifica se há mais capturas disponíveis.
      selectedPiece = Offset(toX.toDouble(), toY.toDouble());
      calculateValidMoves(toX, toY);
      if (validMoves.any((m) => m.isCapture)) {
        print('Mais capturas disponíveis para o Player $currentPlayer');
        return; // Não muda o turno ainda.
      }
    } else {
      try {
        FlameAudio.play('move.mp3');
      } catch (e) {
        print('Erro ao reproduzir move.mp3: $e');
      }
    }

    // Verifica promoções e muda o turno.
    checkForPromotion(toY);
    currentPlayer = currentPlayer == 1 ? 2 : 1;
    selectedPiece = null;
    validMoves.clear();
    movingPiece = null;
    targetPosition = null;
  }

  // Adiciona um efeito de partículas na captura de uma peça.
  void addParticleEffect(int x, int y) {
    final particle = ParticleSystemComponent(
      position: Vector2(
        offsetX + x * tileSize + tileSize / 2,
        offsetY + y * tileSize + tileSize / 2,
      ),
      particle: Particle.generate(
        count: 10,
        lifespan: 0.5,
        generator: (i) => CircleParticle(radius: 5, paint: Paint()..color = Colors.white),
      ),
    );
    add(particle);
  }

  // Calcula os movimentos válidos para uma peça.
  void calculateValidMoves(int x, int y) {
    validMoves.clear();
    int piece = board[y][x];
    bool isKing = (piece == 3 || piece == 4);
    List<List<int>> directions = [
      [-1, -1], // Cima-esquerda
      [1, -1], // Cima-direita
      [-1, 1], // Baixo-esquerda
      [1, 1], // Baixo-direita
    ];

    // Função recursiva para encontrar movimentos e capturas.
    void findMoves(
      int currentX,
      int currentY,
      List<Offset> capturedSoFar,
      Set<String> visited,
      bool hasCaptured,
    ) {
      String currentPos = '$currentX,$currentY';
      if (visited.contains(currentPos)) return;
      visited.add(currentPos);

      if (!isKing) {
        for (var dir in directions) {
          int dx = dir[0];
          int dy = dir[1];
          int newX = currentX + dx;
          int newY = currentY + dy;

          // Movimento simples (uma casa).
          if (!hasCaptured &&
              newX >= 0 &&
              newX < boardSize &&
              newY >= 0 &&
              newY < boardSize &&
              board[newY][newX] == 0) {
            validMoves.add(
              Move(
                Offset(x.toDouble(), y.toDouble()),
                Offset(newX.toDouble(), newY.toDouble()),
              ),
            );
          }

          // Captura (saltar sobre peça inimiga).
          int captureX = currentX + dx * 2;
          int captureY = currentY + dy * 2;
          int midX = currentX + dx;
          int midY = currentY + dy;
          if (captureX >= 0 &&
              captureX < boardSize &&
              captureY >= 0 &&
              captureY < boardSize &&
              board[captureY][captureX] == 0 &&
              board[midY][midX] != 0 &&
              (piece % 2 != board[midY][midX] % 2)) {
            List<Offset> newCaptured = List.from(capturedSoFar)
              ..add(Offset(midX.toDouble(), midY.toDouble()));
            validMoves.add(
              Move(
                Offset(x.toDouble(), y.toDouble()),
                Offset(captureX.toDouble(), captureY.toDouble()),
                isCapture: true,
                capturedPieces: newCaptured,
              ),
            );
            findMoves(captureX, captureY, newCaptured, visited, true);
          }
        }
      } else {
        for (var dir in directions) {
          int dx = dir[0];
          int dy = dir[1];
          int newX = currentX;
          int newY = currentY;

          // Movimento de dama (múltiplas casas na mesma direção).
          while (true) {
            newX += dx;
            newY += dy;

            if (newX < 0 || newX >= boardSize || newY < 0 || newY >= boardSize) {
              break;
            }

            if (board[newY][newX] == 0) {
              if (!hasCaptured) {
                validMoves.add(
                  Move(
                    Offset(x.toDouble(), y.toDouble()),
                    Offset(newX.toDouble(), newY.toDouble()),
                  ),
                );
              }
            } else if (piece % 2 != board[newY][newX] % 2) {
              int nextX = newX + dx;
              int nextY = newY + dy;
              if (nextX >= 0 &&
                  nextX < boardSize &&
                  nextY >= 0 &&
                  nextY < boardSize &&
                  board[nextY][nextX] == 0) {
                List<Offset> newCaptured = List.from(capturedSoFar)
                  ..add(Offset(newX.toDouble(), newY.toDouble()));
                validMoves.add(
                  Move(
                    Offset(x.toDouble(), y.toDouble()),
                    Offset(nextX.toDouble(), nextY.toDouble()),
                    isCapture: true,
                    capturedPieces: newCaptured,
                  ),
                );
                findMoves(nextX, nextY, newCaptured, Set.from(visited), true);
              }
              break;
            } else {
              break;
            }
          }
        }
      }
    }

    findMoves(x, y, [], {}, false);
  }

  // Executa o movimento da IA de forma assíncrona.
  Future<void> _makeAIMoveAsync() async {
    if (isAIThinking) return;
    isAIThinking = true;
    print('IA pensando...');
    await Future.delayed(Duration(milliseconds: 500)); // Simula tempo de pensamento.
    Move? bestMove = await findBestMoveWithTimeout();
    isAIThinking = false;

    if (bestMove != null && !gameOver) {
      int fromX = bestMove.from.dx.toInt();
      int fromY = bestMove.from.dy.toInt();
      int toX = bestMove.to.dx.toInt();
      int toY = bestMove.to.dy.toInt();

      // Aplica o movimento.
      board[toY][toX] = board[fromY][fromX];
      board[fromY][fromX] = 0;

      // Processa capturas.
      if (bestMove.isCapture && bestMove.capturedPieces.isNotEmpty) {
        for (var captured in bestMove.capturedPieces) {
          int midX = captured.dx.toInt();
          int midY = captured.dy.toInt();
          if (board[midY][midX] != 0) {
            board[midY][midX] = 0;
            player1Pieces--;
            player2Captured++;
            try {
              FlameAudio.play('capture.mp3');
            } catch (e) {
              print('Erro ao reproduzir capture.mp3: $e');
            }
            addParticleEffect(midX, midY);
            print('IA capturou peça em ($midX, $midY)');
          }
        }
      } else {
        try {
          FlameAudio.play('move.mp3');
        } catch (e) {
          print('Erro ao reproduzir move.mp3: $e');
        }
        print('IA realizou movimento simples');
      }

      checkForPromotion(toY);
      currentPlayer = 1;
      print(
        'Movimento da IA concluído: de ${bestMove.from} para ${bestMove.to}, captura=${bestMove.isCapture}, peças capturadas=${bestMove.capturedPieces.length}',
      );
    } else {
      print('IA não encontrou movimentos válidos');
    }
    isAITurn = false;
  }

  // Encontra o melhor movimento para a IA com limite de tempo.
  Future<Move?> findBestMoveWithTimeout() async {
    List<Move> allMoves = getAllPossibleMoves(board, 2);
    if (allMoves.isEmpty) {
      print('Nenhum movimento disponível para a IA');
      return null;
    }

    List<Move> captureMoves = allMoves.where((m) => m.isCapture).toList();
    print(
      'Movimentos disponíveis para IA: ${allMoves.map((m) => "${m.to}${m.isCapture ? ' (captura: ${m.capturedPieces.length})' : ''}").toList()}',
    );
    print(
      'Capturas disponíveis para IA: ${captureMoves.map((m) => "${m.to}").toList()}',
    );

    int depth;
    Duration timeout;
    switch (aiDifficulty) {
      case 'easy':
        depth = 3;
        timeout = Duration(seconds: 1);
        break;
      case 'normal':
        depth = 5;
        timeout = Duration(seconds: 2);
        break;
      case 'hard':
        depth = 8;
        timeout = Duration(seconds: 3);
        break;
      default:
        depth = 5;
        timeout = Duration(seconds: 2);
    }

    // Prioriza capturas, se disponíveis.
    if (captureMoves.isNotEmpty) {
      Move? bestCaptureMove;
      int bestScore = -9999;

      for (Move move in captureMoves) {
        List<List<int>> newBoard = cloneBoard(board);
        applyMove(newBoard, move);
        int score =
            -alphaBeta(newBoard, depth - 1, -9999, 9999, false) +
            CAPTURE_BONUS * move.capturedPieces.length;
        if (score > bestScore) {
          bestScore = score;
          bestCaptureMove = move;
        }
      }
      return bestCaptureMove ?? captureMoves[Random().nextInt(captureMoves.length)];
    }

    Move? bestMove;
    int bestScore = -9999;

    // Avalia todos os movimentos com limite de tempo.
    try {
      return await Future.any([
        Future(() async {
          for (Move move in allMoves) {
            List<List<int>> newBoard = cloneBoard(board);
            applyMove(newBoard, move);
            int score = -alphaBeta(newBoard, depth - 1, -9999, 9999, false);
            if (move.isCapture) {
              score += CAPTURE_BONUS * move.capturedPieces.length;
            }
            if (score > bestScore) {
              bestScore = score;
              bestMove = move;
            }
          }
          return bestMove ?? allMoves[Random().nextInt(allMoves.length)];
        }),
        Future.delayed(
          timeout,
          () => allMoves[Random().nextInt(allMoves.length)],
        ),
      ]);
    } catch (e) {
      print('Erro na IA: $e');
      return allMoves[Random().nextInt(allMoves.length)];
    }
  }

  // Algoritmo Alpha-Beta para avaliar movimentos da IA.
  int alphaBeta(
    List<List<int>> board,
    int depth,
    int alpha,
    int beta,
    bool maximizingPlayer,
  ) {
    if (depth == 0 || isGameOver(board)) {
      return evaluateBoard(board);
    }

    List<Move> moves = getAllPossibleMoves(board, maximizingPlayer ? 2 : 1);
    if (moves.isEmpty) return evaluateBoard(board);

    if (maximizingPlayer) {
      int maxEval = -9999;
      for (Move move in moves) {
        List<List<int>> newBoard = cloneBoard(board);
        applyMove(newBoard, move);
        int eval = alphaBeta(newBoard, depth - 1, alpha, beta, false);
        if (move.isCapture) eval += CAPTURE_BONUS * move.capturedPieces.length;
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 9999;
      for (Move move in moves) {
        List<List<int>> newBoard = cloneBoard(board);
        applyMove(newBoard, move);
        int eval = alphaBeta(newBoard, depth - 1, alpha, beta, true);
        if (move.isCapture) eval -= CAPTURE_BONUS * move.capturedPieces.length;
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  // Obtém todos os movimentos possíveis para um jogador.
  List<Move> getAllPossibleMoves(List<List<int>> board, int player) {
    List<Move> moves = [];
    List<Move> captureMoves = [];

    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize; x++) {
        if (board[y][x] == player || board[y][x] == player + 2) {
          calculateValidMoves(x, y);
          moves.addAll(validMoves);
          captureMoves.addAll(validMoves.where((m) => m.isCapture));
        }
      }
    }

    return captureMoves.isNotEmpty ? captureMoves : moves;
  }

  // Avalia o tabuleiro para a IA, considerando peças, posições e capturas.
  int evaluateBoard(List<List<int>> board) {
    int score = 0;

    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize; x++) {
        int piece = board[y][x];
        if (piece == 0) continue;

        int value = (piece == 1 || piece == 2) ? PIECE_VALUE : KING_VALUE;
        if (piece == 2 || piece == 4) {
          score += value;
          score += POSITION_BONUS * (boardSize - y);
          if (x >= 2 && x <= 5 && y >= 2 && y <= 5) {
            score += CENTER_CONTROL_BONUS;
          }
          if (isProtected(x, y, board, 2)) score += PROTECTED_PIECE_BONUS;
        } else {
          score -= value;
          score -= POSITION_BONUS * y;
          if (x >= 2 && x <= 5 && y >= 2 && y <= 5) {
            score -= CENTER_CONTROL_BONUS;
          }
          if (isProtected(x, y, board, 1)) score -= PROTECTED_PIECE_BONUS;
        }
      }
    }
    return score;
  }

  // Verifica se uma peça está protegida por outra peça aliada.
  bool isProtected(int x, int y, List<List<int>> board, int player) {
    int direction = (player == 1 || player == 3) ? 1 : -1;
    List<List<int>> directions = [
      [-1, direction],
      [1, direction],
    ];

    for (var dir in directions) {
      int newX = x + dir[0];
      int newY = y + dir[1];
      if (newX >= 0 &&
          newX < boardSize &&
          newY >= 0 &&
          newY < boardSize &&
          (board[newY][newX] == player || board[newY][newX] == player + 2)) {
        return true;
      }
    }
    return false;
  }

  // Aplica um movimento ao tabuleiro.
  void applyMove(List<List<int>> board, Move move) {
    int fromX = move.from.dx.toInt();
    int fromY = move.from.dy.toInt();
    int toX = move.to.dx.toInt();
    int toY = move.to.dy.toInt();

    board[toY][toX] = board[fromY][fromX];
    board[fromY][fromX] = 0;

    if (move.isCapture) {
      for (var captured in move.capturedPieces) {
        int midX = captured.dx.toInt();
        int midY = captured.dy.toInt();
        board[midY][midX] = 0;
      }
    }

    // Promove peças, se necessário.
    if (board[toY][toX] == 2 && toY == 0) {
      board[toY][toX] = 4;
    } else if (board[toY][toX] == 1 && toY == boardSize - 1) {
      board[toY][toX] = 3;
    }
  }

  // Clona o tabuleiro para simulações da IA.
  List<List<int>> cloneBoard(List<List<int>> board) {
    return board.map((row) => List<int>.from(row)).toList();
  }

  // Verifica se o jogo terminou (um jogador sem peças).
  bool isGameOver(List<List<int>> board) {
    int player1Pieces = 0;
    int player2Pieces = 0;

    for (var row in board) {
      for (var piece in row) {
        if (piece == 1 || piece == 3) player1Pieces++;
        if (piece == 2 || piece == 4) player2Pieces++;
      }
    }

    return player1Pieces == 0 || player2Pieces == 0;
  }

  // Verifica e aplica promoções de peças a damas.
  void checkForPromotion(int y) {
    for (int x = 0; x < boardSize; x++) {
      if (board[y][x] == 1 && y == 0) {
        board[y][x] = 3;
        try {
          FlameAudio.play('promote.mp3');
        } catch (e) {
          print('Erro ao reproduzir promote.mp3: $e');
        }
      } else if (board[y][x] == 2 && y == boardSize - 1) {
        board[y][x] = 4;
        try {
          FlameAudio.play('promote.mp3');
        } catch (e) {
          print('Erro ao reproduzir promote.mp3: $e');
        }
      }
    }
  }

  // Verifica se há um vencedor e atualiza o estado do jogo.
  void checkForWin() {
    if (player1Pieces == 0) {
      gameOver = true;
      winner = isPlayerVsAI ? 'IA' : 'Player 2';
      player2Score++;
      matchHistory.add('$winner venceu');
      try {
        FlameAudio.play('win.mp3');
      } catch (e) {
        print('Erro ao reproduzir win.mp3: $e');
      }
      print('Vitória de $winner');
    } else if (player2Pieces == 0) {
      gameOver = true;
      winner = 'Player 1';
      player1Score++;
      matchHistory.add('Player 1 venceu');
      try {
        FlameAudio.play('win.mp3');
      } catch (e) {
        print('Erro ao reproduzir win.mp3: $e');
      }
      print('Vitória do Player 1');
    }
  }
}

// Função principal que inicializa o aplicativo Flutter.
void main() {
  final myGame = MyGame();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          child: GestureDetector(
            onTapDown: (details) => myGame.onTapDown(details),
            child: GameWidget(
              game: myGame,
              overlayBuilderMap: {
                'MainMenu': (context, game) => buildOverlay(context, game as MyGame, 'MainMenu'),
                'DifficultyMenu': (context, game) => buildOverlay(context, game as MyGame, 'DifficultyMenu'),
                'History': (context, game) => buildOverlay(context, game as MyGame, 'History'),
                'About': (context, game) => buildOverlay(context, game as MyGame, 'About'),
              },
              initialActiveOverlays: const ['MainMenu'],
            ),
          ),
        ),
      ),
    ),
  );
}

// Constrói os overlays (telas de interface) do jogo.
Widget buildOverlay(BuildContext context, MyGame game, String overlayType) {
  switch (overlayType) {
    case 'MainMenu':
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Jogo de Damas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    game.isPlayerVsAI = false;
                    game.resetGame();
                    game.overlays.remove('MainMenu');
                  },
                  child: Text(
                    'Jogador vs Jogador',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    game.isPlayerVsAI = true;
                    game.overlays.remove('MainMenu');
                    game.overlays.add('DifficultyMenu');
                  },
                  child: Text(
                    'Jogador vs IA',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    game.overlays.remove('MainMenu');
                    game.overlays.add('History');
                  },
                  child: Text(
                    'Histórico',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    game.overlays.remove('MainMenu');
                    game.overlays.add('About');
                  },
                  child: Text(
                    'Sobre',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    case 'DifficultyMenu':
      return Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.brown.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escolha a Dificuldade da IA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  game.aiDifficulty = 'easy';
                  game.isPlayerVsAI = true;
                  game.resetGame();
                  game.overlays.clear();
                },
                child: Text(
                  'Fácil',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  game.aiDifficulty = 'normal';
                  game.isPlayerVsAI = true;
                  game.resetGame();
                  game.overlays.clear();
                },
                child: Text(
                  'Normal',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  game.aiDifficulty = 'hard';
                  game.isPlayerVsAI = true;
                  game.resetGame();
                  game.overlays.clear();
                },
                child: Text(
                  'Difícil',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  game.overlays.remove('DifficultyMenu');
                  game.overlays.add('MainMenu');
                },
                child: Text(
                  'Voltar',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    case 'History':
      final matchHistory = game.matchHistory;
      return Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.brown.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Histórico de Partidas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                matchHistory.isEmpty ? 'Nenhuma partida registrada' : matchHistory.join('\n'),
                style: TextStyle(color: Colors.white, fontSize: 24),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  game.overlays.remove('History');
                  game.overlays.add('MainMenu');
                },
                child: Text(
                  'Voltar',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    case 'About':
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sobre o Jogo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    const url = 'https://github.com/MichaelDouglasCA';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      print('Não foi possível abrir o URL: $url');
                    }
                  },
                  child: Text(
                    'Desenvolvido por: MichaelDCA\nVersão: 1.0.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    game.overlays.remove('About');
                    game.overlays.add('MainMenu');
                  },
                  child: Text(
                    'Voltar',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    default:
      return Container();
  }
}