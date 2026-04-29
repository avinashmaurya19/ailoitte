import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'db_helper.dart';
import 'models.dart';

class SyncMetrics {
  final int successCount;
  final int failCount;
  final int pendingQueueSize;

  const SyncMetrics({
    required this.successCount,
    required this.failCount,
    required this.pendingQueueSize,
  });

  factory SyncMetrics.initial() =>
      const SyncMetrics(successCount: 0, failCount: 0, pendingQueueSize: 0);

  SyncMetrics copyWith({
    int? successCount,
    int? failCount,
    int? pendingQueueSize,
  }) {
    return SyncMetrics(
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      pendingQueueSize: pendingQueueSize ?? this.pendingQueueSize,
    );
  }
}

class SyncManager {
  final DBHelper db;
  final firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  bool _simulateOneTransientFailure = false;
  final ValueNotifier<SyncMetrics> metrics = ValueNotifier<SyncMetrics>(
    SyncMetrics.initial(),
  );

  SyncManager(this.db);

  void enableSingleFailureSimulation() {
    _simulateOneTransientFailure = true;
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final actions = await db.getQueue();
      await _refreshPendingQueueMetric();

      debugPrint("QUEUE SIZE: ${actions.length}");

      for (var a in actions) {
        try {
          final action = SyncAction.fromMap(a);
          final data = jsonDecode(a["payload"]);
          final noteId = data["id"]?.toString() ?? action.noteId;

          if (_simulateOneTransientFailure) {
            _simulateOneTransientFailure = false;
            throw Exception("Simulated transient failure");
          }
          if (action.type == "delete_note") {
            await firestore.collection("notes").doc(noteId).delete();
          } else {
            await firestore
                .collection("notes")
                .doc(noteId) // idempotency key is document id + set merge
                .set(data, SetOptions(merge: true));
          }

          await db.deleteQueue(action.id);
          metrics.value = metrics.value.copyWith(
            successCount: metrics.value.successCount + 1,
          );
          await _refreshPendingQueueMetric();

          debugPrint("SYNC SUCCESS: ${action.id}");
        } catch (e) {
          final action = SyncAction.fromMap(a);
          final retry = action.retryCount + 1;
          final errorDetails = _formatSyncError(e);

          if (retry <= 1) {
            await Future.delayed(const Duration(seconds: 2));
            await db.updateRetry(action.id, retry);
            await db.updateQueueStatus(action.id, "pending");
            debugPrint(
              "SYNC RETRY SCHEDULED: ${action.id} retry=$retry error=$errorDetails",
            );
          } else {
            await db.updateRetry(action.id, retry);
            await db.updateQueueStatus(action.id, "failed");
            metrics.value = metrics.value.copyWith(
              failCount: metrics.value.failCount + 1,
            );
            await _refreshPendingQueueMetric();
            debugPrint("SYNC FAILED: ${action.id} error=$errorDetails");
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _refreshPendingQueueMetric() async {
    final pendingSize = await db.getPendingQueueSize();
    metrics.value = metrics.value.copyWith(pendingQueueSize: pendingSize);
  }

  String _formatSyncError(Object error) {
    if (error is FirebaseException) {
      return "code=${error.code} message=${error.message}";
    }
    return error.toString();
  }
}
