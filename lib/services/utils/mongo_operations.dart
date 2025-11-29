class MongoOperations {
  Map<String, dynamic> upsertOperation(
    String collection,
    Map<String, dynamic> data,
  ) {
    String documentId;

    if (data.containsKey("_id")) {
      documentId = data["_id"];
    } else if (data.containsKey("id")) {
      documentId = data["id"];
    } else {
      documentId = "";
    }

    return {
      "operation": "upsert",
      "type": "upsert",
      "collection": collection,
      "query": {"_id": documentId},
      "update": data,
    };
  }

  Map<String, dynamic> updateOperation(
    String collection,
    Map<String, dynamic> query,
    Map<String, dynamic> data,
  ) {
    return {
      "operation": "update",
      "type": "update",
      "collection": collection,
      "query": query,
      "update": data,
    };
  }

  Map<String, dynamic> getOperation(String collection, String id) {
    return {
      "operation": "get",
      "type": "get",
      "collection": collection,
      "id": id,
      "query": {"_id": id},
    };
  }

  Map<String, dynamic> deleteOperation(
    String collection,
    Map<String, dynamic> query,
  ) {
    return {
      "operation": "delete",
      "type": "delete",
      "collection": collection,
      "query": query,
    };
  }

  Map<String, dynamic> findOperation(
    String collection,
    Map<String, dynamic> query,
  ) {
    return {"operation": "find", "collection": collection, "query": query};
  }

  Map<String, dynamic> pushOperation(
    String collection,
    String id,
    String field,
    dynamic value,
  ) {
    return {
      "operation": "push",
      "type": "push",
      "collection": collection,
      "id": id,
      "field": field,
      "value": value,
    };
  }

  Map<String, dynamic> likedJournalOperation(
    String eventId,
    String uuid,
    String journalUserId,
  ) {
    return {
      "operation": "likedJournalOperation",
      "type": "likedJournalOperation",
      "eventId": eventId,
      "uuid": uuid,
      "journalUserId": journalUserId,
    };
  }

  Map<String, dynamic> superLikedJournalOperation(
    String eventId,
    String uuid,
    String journalUserId,
  ) {
    return {
      "operation": "likedJournalOperation",
      "type": "superLikedJournalOperation",
      "eventId": eventId,
      "uuid": uuid,
      "journalUserId": journalUserId,
    };
  }

  Map<String, dynamic> pullOperation(
    String collection,
    String id,
    String field,
    dynamic value,
  ) {
    return {
      "operation": "pull",
      "type": "pull",
      "collection": collection,
      "id": id,
      "field": field,
      "value": value,
    };
  }

  Map<String, dynamic> chatOperation(
    String collection,
    String id,
    String field,
    dynamic value,
  ) {
    return {
      "operation": "chatOperation",
      "collection": collection,
      "id": id,
      "field": field,
      "value": value,
    };
  }
}
