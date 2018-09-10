import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:trufi_app/location/location_search_favorites.dart';
import 'package:trufi_app/trufi_models.dart';

const String Endpoint = 'trufiapp.westeurope.cloudapp.azure.com';
const String SearchPath = '/otp/routers/default/geocode';
const String PlanPath = 'otp/routers/default/plan';
const String StopsPath = 'otp/routers/default/index/stops';
const String LinesPath = 'otp/routers/default/index/stops/{stop_id}/routes';

class FetchRequestException implements Exception {
  final Exception _innerException;

  FetchRequestException(this._innerException);

  String toString() {
    return "Fetch request exception caused by: ${_innerException.toString()}";
  }
}

class FetchResponseException implements Exception {
  final String _message;

  FetchResponseException(this._message);

  @override
  String toString() {
    return "FetchResponseException: $_message";
  }
}

Future<List<TrufiLocation>> fetchLocations(String query) async {
  Uri request = Uri.https(Endpoint, SearchPath, {
    "query": query,
    "autocomplete": "false",
    "corners": "true",
    "stops": "false"
  });
  final response = await fetchRequest(request);
  if (response.statusCode == 200) {
    List<TrufiLocation> locations =
        await compute(_parseLocations, utf8.decode(response.bodyBytes));
    locations.sort(sortByFavorite);
    return locations;
  } else {
    throw FetchResponseException('Failed to load locations');
  }
}

List<TrufiLocation> _parseLocations(String responseBody) {
  return json
      .decode(responseBody)
      .map<TrufiLocation>((json) => new TrufiLocation.fromSearchJson(json))
      .toList();
}

Future<Plan> fetchPlan(TrufiLocation from, TrufiLocation to) async {
  Uri request = Uri.https(Endpoint, PlanPath, {
    "fromPlace": from.toString(),
    "toPlace": to.toString(),
    "date": "01-01-2018",
    "mode": "TRANSIT,WALK"
  });
  final response = await fetchRequest(request);
  if (response.statusCode == 200) {
    return compute(_parsePlan, utf8.decode(response.bodyBytes));
  } else {
    throw FetchResponseException('Failed to load plan');
  }
}

Plan _parsePlan(String responseBody) {
  return Plan.fromJson(json.decode(responseBody));
}

Future<http.Response> fetchRequest(Uri request) async {
  try {
    return await http.get(request);
  } catch (e) {
    throw FetchRequestException(e);
  }
}

Future<List<Stop>> fetchStops(TrufiLocation currentLocation) async {
  Uri request = Uri.https(Endpoint, StopsPath, {
    "lat": currentLocation.latitude.toString(),
    "lon": currentLocation.longitude.toString(),
    "radius": "300"
  });
  final response = await fetchRequest(request);
  if (response.statusCode == 200) {
    return await compute(_parseStop, utf8.decode(response.bodyBytes));
  } else {
    throw FetchResponseException('Failed to load stops nearby');
  }
}

List<Stop> _parseStop(String responseBody) {
  print(responseBody);
  return json
      .decode(responseBody)
      .map<Stop>((json) => new Stop.fromJson(json))
      .toList();
}

Future<List<String>> fetchRoutes(Stop stop) async {
  String linesPathWithStopId = LinesPath.replaceAll('{stop_id}', stop.id);
  Uri request = Uri.https(Endpoint, linesPathWithStopId);
  print(request);
  final response = await fetchRequest(request);
  if (response.statusCode == 200) {
    return await compute(_parseRoute, utf8.decode(response.bodyBytes));
  } else {
    throw FetchResponseException('Failed to load routes nearby');
  }
}

List<String> _parseRoute(String responseBody) {
  print(responseBody);
  return json
      .decode(responseBody)
      .map<Stop>((json) => new Stop.fromJson(json))
      .toList();
}
