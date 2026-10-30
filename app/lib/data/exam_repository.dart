import '../domain/models.dart';

abstract class ExamRepository {
  Future<List<Exam>> loadCatalog();
  Future<List<Sitting>> loadSittings(String examId);
  Future<List<Publication>> loadPublications(ExamSelection selection);
  Future<ResultVersion?> loadResultVersion(ExamSelection selection);
}

class ServiceUnavailable implements Exception {
  const ServiceUnavailable();
}
