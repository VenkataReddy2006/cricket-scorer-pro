import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/match.dart';
import '../models/player.dart';
import 'package:intl/intl.dart';

class PdfPreviewScreen extends StatelessWidget {
  final MatchModel match;
  final List<Player> players;

  const PdfPreviewScreen({super.key, required this.match, required this.players});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Export Scorecard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PdfPreview(
        build: (format) => generatePdf(format, match, players),
        maxPageWidth: 700,
        canDebug: false,
      ),
    );
  }

  static Future<Uint8List> generatePdf(
    PdfPageFormat format,
    MatchModel match,
    List<Player> players,
  ) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(match.date);

    pw.Font font;
    pw.Font fontBold;
    try {
      font = await PdfGoogleFonts.interRegular();
      fontBold = await PdfGoogleFonts.interBold();
    } catch (e) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final textStyle = pw.TextStyle(font: font, fontSize: 9);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold);

    String getPlayerName(String? id) {
      if (id == null || id.isEmpty) return 'Unknown';
      final p = players.firstWhere(
        (element) => element.id == id,
        orElse: () => Player(id: '', name: 'Unknown'),
      );
      return p.name;
    }

    Map<dynamic, dynamic> getPlayerStats(String id) {
      final playerStats = match.matchData['playerStats'] != null
          ? Map<dynamic, dynamic>.from(match.matchData['playerStats'])
          : {};
      return playerStats[id] ?? {};
    }

    pw.Widget buildInningsSection(
      String teamName,
      int score,
      int wickets,
      double overs,
      int inningsNum,
      List<dynamic> battingTeamIds,
      List<dynamic> bowlingTeamIds,
    ) {
      final batsmen = players.where((p) => battingTeamIds.contains(p.id)).toList();
      final bowlers = players.where((p) => bowlingTeamIds.contains(p.id)).toList();
      final strikerId = match.matchData['strikerId'];
      final team1Captain = match.matchData['team1Captain'];
      final team2Captain = match.matchData['team2Captain'];
      final retiredPlayerIds = match.matchData['retiredPlayerIds'] ?? [];

      final activeBatsmen = batsmen.where((p) {
        final stats = getPlayerStats(p.id);
        return (stats['balls'] ?? 0) > 0 || p.id == strikerId || retiredPlayerIds.contains(p.id);
      }).toList();

      final activeBowlers = bowlers.where((p) {
        final stats = getPlayerStats(p.id);
        return (stats['bowledBalls'] ?? 0) > 0;
      }).toList();

      final yetToBat = batsmen.where((p) => !activeBatsmen.contains(p)).toList();

      final List<dynamic> balls = match.matchData['balls_$inningsNum'] ?? [];

      List<Map<String, dynamic>> partnershipsList = [];
      if (balls.isNotEmpty) {
        String? currentPStrikerId;
        String? currentPNonStrikerId;
        int runs = 0;
        int totalBalls = 0;
        int strikerRuns = 0;
        int strikerBalls = 0;
        int nonStrikerRuns = 0;
        int nonStrikerBalls = 0;
        int extras = 0;

        for (var ball in balls) {
          String strikerId = ball['strikerId'] ?? '';
          String nonStrikerId = ball['nonStrikerId'] ?? '';

          if (currentPStrikerId == null || currentPNonStrikerId == null) {
            currentPStrikerId = strikerId;
            currentPNonStrikerId = nonStrikerId;
          }

          bool isSamePair = (strikerId == currentPStrikerId && nonStrikerId == currentPNonStrikerId) ||
                            (strikerId == currentPNonStrikerId && nonStrikerId == currentPStrikerId);

          if (!isSamePair) {
            partnershipsList.add({
              'strikerId': currentPStrikerId,
              'nonStrikerId': currentPNonStrikerId,
              'runs': runs,
              'balls': totalBalls,
              'strikerRuns': strikerRuns,
              'strikerBalls': strikerBalls,
              'nonStrikerRuns': nonStrikerRuns,
              'nonStrikerBalls': nonStrikerBalls,
              'extras': extras,
              'wicketNumber': partnershipsList.length + 1,
            });

            currentPStrikerId = strikerId;
            currentPNonStrikerId = nonStrikerId;
            runs = 0;
            totalBalls = 0;
            strikerRuns = 0;
            strikerBalls = 0;
            nonStrikerRuns = 0;
            nonStrikerBalls = 0;
            extras = 0;
          }

          bool isRetirement = ball['isRetirement'] ?? false;
          if (isRetirement) {
            partnershipsList.add({
              'strikerId': currentPStrikerId,
              'nonStrikerId': currentPNonStrikerId,
              'runs': runs,
              'balls': totalBalls,
              'strikerRuns': strikerRuns,
              'strikerBalls': strikerBalls,
              'nonStrikerRuns': nonStrikerRuns,
              'nonStrikerBalls': nonStrikerBalls,
              'extras': extras,
              'wicketNumber': partnershipsList.length + 1,
              'isRetired': true,
            });

            String retiringId = ball['retiringBatsmanId'] ?? '';
            String nextId = ball['nextBatsmanId'] ?? '';
            if (currentPStrikerId == retiringId) {
              currentPStrikerId = nextId;
            } else {
              currentPNonStrikerId = nextId;
            }
            runs = 0;
            totalBalls = 0;
            strikerRuns = 0;
            strikerBalls = 0;
            nonStrikerRuns = 0;
            nonStrikerBalls = 0;
            extras = 0;
            continue;
          }

          int ballRuns = ball['runs'] ?? 0;
          bool isWide = ball['isWide'] ?? false;
          bool isByes = ball['isByes'] ?? false;
          bool isLegByes = ball['isLegByes'] ?? false;
          int runsToAdd = ball['runsToAdd'] ?? ballRuns;

          runs += runsToAdd;
          if (!isWide) {
            totalBalls++;
          }

          if (strikerId == currentPStrikerId) {
            if (!isWide) {
              strikerBalls++;
              if (!isByes && !isLegByes) {
                strikerRuns += ballRuns;
              }
            }
          } else {
            if (!isWide) {
              nonStrikerBalls++;
              if (!isByes && !isLegByes) {
                nonStrikerRuns += ballRuns;
              }
            }
          }

          int batRuns = 0;
          if (!isWide && !isByes && !isLegByes) {
            batRuns = ballRuns;
          }
          int ballExtras = runsToAdd - batRuns;
          if (ballExtras > 0) {
            extras += ballExtras;
          }
        }

        if (currentPStrikerId != null && currentPNonStrikerId != null) {
          partnershipsList.add({
            'strikerId': currentPStrikerId,
            'nonStrikerId': currentPNonStrikerId,
            'runs': runs,
            'balls': totalBalls,
            'strikerRuns': strikerRuns,
            'strikerBalls': strikerBalls,
            'nonStrikerRuns': nonStrikerRuns,
            'nonStrikerBalls': nonStrikerBalls,
            'extras': extras,
            'wicketNumber': partnershipsList.length + 1,
            'isActive': true,
          });
        }
      }

      final fowList = balls.where((b) => b['isWicket'] == true).toList();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$teamName Innings',
                  style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '$score-$wickets (${overs.toStringAsFixed(1)} Overs)',
                  style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          if (activeBatsmen.isNotEmpty) ...[
            pw.Text('Batting', style: pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Batsman', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('R', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('B', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('4s', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('6s', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('SR', style: headerStyle)),
                  ],
                ),
                ...activeBatsmen.map((p) {
                  final stats = getPlayerStats(p.id);
                  int runs = stats['runs'] ?? 0;
                  int ballsCount = stats['balls'] ?? 0;
                  String sr = ballsCount == 0
                      ? '0.00'
                      : ((runs / ballsCount) * 100).toStringAsFixed(2);
                  String displayName = p.name;
                  if (p.id == team1Captain || p.id == team2Captain) displayName += ' (C)';
                  if (p.id == strikerId) displayName += '*';
                  if (retiredPlayerIds.contains(p.id)) displayName += ' (retired)';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(displayName, style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$runs', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$ballsCount', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${stats['4s'] ?? 0}', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${stats['6s'] ?? 0}', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(sr, style: textStyle)),
                    ],
                  );
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 8),

          if (activeBowlers.isNotEmpty) ...[
            pw.Text('Bowling', style: pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Bowler', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('O', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('M', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('R', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('W', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('ER', style: headerStyle)),
                  ],
                ),
                ...activeBowlers.map((p) {
                  final stats = getPlayerStats(p.id);
                  int runs = stats['runsConceded'] ?? 0;
                  int ballsCount = stats['bowledBalls'] ?? 0;
                  String oversStr = '${ballsCount ~/ 6}.${ballsCount % 6}';
                  String er = ballsCount == 0
                      ? '0.00'
                      : (runs / (ballsCount / 6)).toStringAsFixed(2);
                  String displayName = p.name;
                  if (p.id == team1Captain || p.id == team2Captain) displayName += ' (C)';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(displayName, style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(oversStr, style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${stats['maidens'] ?? 0}', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$runs', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${stats['wickets'] ?? 0}', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(er, style: textStyle)),
                    ],
                  );
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 8),

          if (yetToBat.isNotEmpty) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Yet to bat: ', style: boldStyle),
                pw.Expanded(
                  child: pw.Text(
                    yetToBat.map((p) => (p.id == team1Captain || p.id == team2Captain) ? '${p.name} (C)' : p.name).join(', '),
                    style: textStyle,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          if (partnershipsList.isNotEmpty) ...[
            pw.Text('Partnerships', style: pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Wkt', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Batsmen', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Runs (Balls)', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Contributions', style: headerStyle)),
                  ],
                ),
                ...partnershipsList.map((p) {
                  String sName = getPlayerName(p['strikerId']);
                  String nsName = getPlayerName(p['nonStrikerId']);
                  int pRuns = p['runs'] ?? 0;
                  int pBalls = p['balls'] ?? 0;
                  int sRuns = p['strikerRuns'] ?? 0;
                  int sBalls = p['strikerBalls'] ?? 0;
                  int nsRuns = p['nonStrikerRuns'] ?? 0;
                  int nsBalls = p['nonStrikerBalls'] ?? 0;
                  String wktNum = '${p['wicketNumber']}';
                  if (p['isRetired'] == true) wktNum += ' (Ret)';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(wktNum, style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$sName & $nsName', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$pRuns ($pBalls)', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$sName: $sRuns ($sBalls) | $nsName: $nsRuns ($nsBalls)', style: textStyle)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 8),
          ],

          if (fowList.isNotEmpty) ...[
            pw.Text('Fall of Wickets', style: pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Wkt', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Score', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Batsman Out', style: headerStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Over', style: headerStyle)),
                  ],
                ),
                ...fowList.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var w = entry.value;
                  int wNum = idx + 1;
                  int scoreAtW = w['teamScore'] ?? 0;
                  int wicketsAtW = w['teamWickets'] ?? 0;
                  String batsmanName = getPlayerName(w['batsmanOutId'] ?? w['strikerId']);
                  String overStr = '${w['over'] ?? '0.0'}';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$wNum', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$scoreAtW-$wicketsAtW', style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(batsmanName, style: textStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(overStr, style: textStyle)),
                    ],
                  );
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 16),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${match.team1Name} vs ${match.team2Name}',
                    style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey300)),
                      pw.Text('Overs: ${match.overs}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey300)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Result: ${match.result}',
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.amber, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            buildInningsSection(
              match.team1Name,
              match.team1Score,
              match.team1Wickets,
              match.team1Overs,
              1,
              match.matchData['team1Players'] ?? [],
              (match.matchData['type'] == 'single_mode' || match.matchData['type'] == 'pair_mode')
                  ? (match.matchData['team1Players'] ?? [])
                  : (match.matchData['team2Players'] ?? []),
            ),

            if (match.matchData['type'] != 'single_mode' && match.matchData['type'] != 'pair_mode')
              buildInningsSection(
                match.team2Name,
                match.team2Score,
                match.team2Wickets,
                match.team2Overs,
                2,
                match.matchData['team2Players'] ?? [],
                match.matchData['team1Players'] ?? [],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
