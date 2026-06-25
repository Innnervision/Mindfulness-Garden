import 'package:logger/logger.dart';
import 'package:universe_backend_sdk/universe_backend_sdk.dart';

/// Backend integration service for Mindfulness Garden
/// Handles all backend communication replacing Firebase
class BackendIntegrationService {
  final Logger _logger = Logger();
  UniverseBackendClient? _client;
  GameIntegrationHelper? _gameHelper;
  AuthService? _authService;
  GameService? _gameService;
  
  static const String _gameName = 'Mindfulness Garden';
  static const String _backendUrl = 'http://localhost:8000';

  Future<void> initialize() async {
    try {
      final config = UniverseBackendConfig(apiUrl: _backendUrl, enableLogging: true);
      _client = UniverseBackendClient(config: config);
      _authService = AuthService(client: _client!);
      _gameService = GameService(repository: GameRepository(client: _client!));
      
      final achievementService = AchievementService(repository: AchievementRepository(client: _client!));
      final leaderboardService = LeaderboardService(repository: LeaderboardRepository(client: _client!));
      
      _gameHelper = GameIntegrationHelper(
        client: _client!,
        gameService: _gameService!,
        achievementService: achievementService,
        leaderboardService: leaderboardService,
      );
      _logger.i('Backend integration service initialized for Mindfulness Garden');
    } catch (e) {
      _logger.e('Failed to initialize backend service', error: e);
      rethrow;
    }
  }

  UniverseBackendClient? get client => _client;
  GameIntegrationHelper? get gameHelper => _gameHelper;
  AuthService? get authService => _authService;

  Future<bool> login(String email, String password) async {
    try {
      if (_authService == null) throw Exception('Backend service not initialized');
      final result = await _authService!.login(email, password);
      if (result.success && result.tokens != null) {
        await _client!.tokenManager.setAccessToken(result.tokens!.accessToken);
        await _client!.tokenManager.setRefreshToken(result.tokens!.refreshToken);
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Login failed', error: e);
      return false;
    }
  }

  Future<bool> register(String email, String password, String firstName, String lastName) async {
    try {
      if (_authService == null) throw Exception('Backend service not initialized');
      final result = await _authService!.register(email: email, password: password, firstName: firstName, lastName: lastName);
      return result.success;
    } catch (e) {
      _logger.e('Registration failed', error: e);
      return false;
    }
  }

  Future<void> logout() async {
    await _client?.tokenManager.clearTokens();
  }

  Future<bool> isAuthenticated() async {
    final token = await _client?.tokenManager.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<GameIntegrationResult?> initializeGame() async {
    try {
      if (_gameHelper == null) throw Exception('Game helper not initialized');
      return await _gameHelper!.initializeGame(_gameName);
    } catch (e) {
      _logger.e('Failed to initialize game', error: e);
      return null;
    }
  }

  Future<GameSession?> startSession({Map<String, dynamic>? deviceInfo}) async {
    try {
      final games = await _gameService!.listGames();
      final game = games.results.firstWhere((g) => g.name == _gameName, orElse: () => throw Exception('Game not found'));
      return await _gameHelper!.startSession(game.id, deviceInfo: deviceInfo);
    } catch (e) {
      _logger.e('Failed to start session', error: e);
      return null;
    }
  }

  Future<GameSession?> endSession(int sessionId, int score, {Map<String, dynamic>? sessionData}) async {
    try {
      return await _gameHelper!.endSession(sessionId, score, sessionData: sessionData);
    } catch (e) {
      _logger.e('Failed to end session', error: e);
      return null;
    }
  }

  Future<GameProgress?> updateProgress({int? level, int? experiencePoints, int? highScore, Map<String, dynamic>? gameStats}) async {
    try {
      final games = await _gameService!.listGames();
      final game = games.results.firstWhere((g) => g.name == _gameName, orElse: () => throw Exception('Game not found'));
      return await _gameHelper!.updateProgress(game.id, level: level, experiencePoints: experiencePoints, highScore: highScore, gameStats: gameStats);
    } catch (e) {
      _logger.e('Failed to update progress', error: e);
      return null;
    }
  }

  void dispose() {
    _client?.dispose();
  }
}
