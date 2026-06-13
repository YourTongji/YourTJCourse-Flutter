import 'json_helpers.dart';

/// Transaction status matching credit serverless TransactionStatus enum.
enum TxStatus { pending, completed, cancelled, disputed }

/// Parsed from the serverless Transaction type.
class Transaction {
  const Transaction({
    required this.id,
    this.txId,
    required this.typeName,
    required this.typeDisplayName,
    this.fromUserHash,
    this.toUserHash,
    required this.amount,
    required this.status,
    required this.title,
    this.description,
    required this.createdAt,
    this.completedAt,
  });

  factory Transaction.fromJson(Object? json) {
    final map = asJsonMap(json);
    return Transaction(
      id: readInt(map['id']) ?? 0,
      txId: readString(map['txId']),
      typeName: readString(map['typeName']) ?? '',
      typeDisplayName: readString(map['typeDisplayName']) ?? '',
      fromUserHash: readString(map['fromUserHash']),
      toUserHash: readString(map['toUserHash']),
      amount: readInt(map['amount']) ?? 0,
      status: _parseStatus(readString(map['status'])),
      title: readString(map['title']) ?? '',
      description: readString(map['description']),
      createdAt: readInt(map['createdAt']) ?? 0,
      completedAt: readInt(map['completedAt']),
    );
  }

  final int id;
  final String? txId;
  final String typeName;
  final String typeDisplayName;
  final String? fromUserHash;
  final String? toUserHash;
  final int amount;
  final TxStatus status;
  final String title;
  final String? description;
  final int createdAt;
  final int? completedAt;

  /// True if this transaction is a credit (inflow) for the given userHash.
  bool isCredit(String userHash) => toUserHash == userHash;

  /// True if this transaction is a debit (outflow) from the given userHash.
  bool isDebit(String userHash) => fromUserHash == userHash && toUserHash != userHash;

  DateTime get createdAtDt => DateTime.fromMillisecondsSinceEpoch(createdAt);
  DateTime? get completedAtDt => completedAt != null ? DateTime.fromMillisecondsSinceEpoch(completedAt!) : null;

  static TxStatus _parseStatus(String? s) {
    return switch (s) {
      'pending' => TxStatus.pending,
      'cancelled' => TxStatus.cancelled,
      'disputed' => TxStatus.disputed,
      _ => TxStatus.completed,
    };
  }
}

/// Paginated transaction list matching `PaginatedResponse<Transaction>`.
class PaginatedTransactions {
  const PaginatedTransactions({
    required this.transactions,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedTransactions.fromJson(Object? json) {
    final map = asJsonMap(json);
    final dataList = map['data'];
    return PaginatedTransactions(
      transactions: dataList is List
          ? dataList.map(Transaction.fromJson).toList(growable: false)
          : const [],
      total: readInt(map['total']) ?? 0,
      page: readInt(map['page']) ?? 1,
      limit: readInt(map['limit']) ?? 20,
      totalPages: readInt(map['totalPages']) ?? 0,
    );
  }

  final List<Transaction> transactions;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
