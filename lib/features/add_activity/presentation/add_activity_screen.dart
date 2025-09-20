import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_activity/presentation/bloc/activities_bloc.dart';
import 'package:opennutritracker/features/add_activity/presentation/bloc/recent_activities_bloc.dart';
import 'package:opennutritracker/features/add_activity/presentation/widgets/activity_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
// import 'package:opennutritracker/health_connect_service.dart'; 


class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _day;

  late ActivitiesBloc _activitiesBloc;
  late RecentActivitiesBloc _recentActivitiesBloc;

  late TabController _tabController;

  @override
  void initState() {
    _activitiesBloc = locator<ActivitiesBloc>();
    _recentActivitiesBloc = locator<RecentActivitiesBloc>();
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)!.settings.arguments
        as AddActivityScreenArguments;
    _day = args.day;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  @override
  void _importFromHealthConnect() async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Authorize and fetch activities from Health Connect
      final isAuthorized = await HealthConnectService.authorize();
      if (!isAuthorized) {
        throw Exception('Permission to Health Connect denied.');
      }
      
      final activities = await HealthConnectService.fetchActivities();
      if (activities.isEmpty) {
        throw Exception('No recent activities found in Health Connect.');
      }

      final lastActivity = activities.last;
      final activityName = lastActivity['name'] as String;
      final activityDuration = lastActivity['duration'] as int;

      // 2. Find a matching activity within the app
      final currentState = _activitiesBloc.state;
      if (currentState is! ActivitiesLoadedState) {
        throw Exception('App activities not loaded yet. Please wait a moment.');
      }

      final appActivities = currentState.activities;
      final matchedActivity = appActivities.firstWhere(
        (activity) => activity.name.toLowerCase() == activityName.toLowerCase(),
        orElse: () => throw Exception('Activity "$activityName" not found in the app.'),
      );

      // 3. Save the matched activity with the imported duration using the existing BLoC
      _recentActivitiesBloc.add(SaveRecentActivityEvent(
        context: context,
        physicalActivity: matchedActivity,
        duration: activityDuration,
        day: _day,
      ));
      
      // Close the loading indicator
      Navigator.of(context).pop(); 
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $activityName!')),
      );

    } catch (e) {
      // Close the loading indicator and show an error message
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    }
  }





  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).activityLabel),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: S.of(context).searchLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    )),
                onChanged: (String searchString) {
                  _activitiesBloc.add(SearchActivitiesEvent(
                      context: context, searchString: searchString));
                },
              ),

              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Import from Health Connect'),
                onPressed: _importFromHealthConnect,
              ),
              
              const SizedBox(height: 16.0),
              TabBar(
                  tabs: [
                    Tab(text: S.of(context).allItemsLabel),
                    Tab(text: S.of(context).recentlyAddedLabel)
                  ],
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab),
              const SizedBox(height: 16),
              Expanded(
                  child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      BlocBuilder<ActivitiesBloc, ActivitiesState>(
                        bloc: _activitiesBloc,
                        builder: (context, state) {
                          if (state is ActivitiesInitial) {
                            _activitiesBloc
                                .add(LoadActivitiesEvent(context: context));
                            return const SizedBox();
                          }
                          if (state is ActivitiesLoadingState) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (state is ActivitiesLoadedState) {
                            final physicalActivities = state.activities;
                            return Flexible(
                              child: ListView.builder(
                                  itemCount: physicalActivities.length,
                                  itemBuilder: (context, index) {
                                    return ActivityItemCard(
                                        physicalActivityEntity:
                                            physicalActivities[index],
                                        day: _day);
                                  }),
                            );
                          }
                          if (state is ActivitiesFailedState) {
                            return ErrorDialog(
                              errorText: S.of(context).errorLoadingActivities,
                              onRefreshPressed:
                                  _onActivitiesRefreshButtonPressed,
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      BlocBuilder<RecentActivitiesBloc, RecentActivitiesState>(
                        bloc: _recentActivitiesBloc,
                        builder: (context, state) {
                          if (state is RecentActivitiesInitial) {
                            _recentActivitiesBloc.add(
                                LoadRecentActivitiesEvent(context: context));
                            return const SizedBox();
                          }
                          if (state is RecentActivitiesLoadingState) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (state is RecentActivitiesLoadedState) {
                            final recentActivities = state.recentActivities;
                            return state.recentActivities.isNotEmpty
                                ? Flexible(
                                    child: ListView.builder(
                                        itemCount: recentActivities.length,
                                        itemBuilder: (context, index) {
                                          return ActivityItemCard(
                                            physicalActivityEntity:
                                                recentActivities[index],
                                            day: _day,
                                          );
                                        }),
                                  )
                                : const NoResultsWidget();
                          }
                          if (state is RecentActivitiesFailedState) {
                            return ErrorDialog(
                              errorText: S.of(context).errorLoadingActivities,
                              onRefreshPressed:
                                  _onRecentActivitiesRefreshButtonPressed,
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ],
              )),
            ],
          ),
        ));
  }

  void _onActivitiesRefreshButtonPressed() {
    _activitiesBloc.add(LoadActivitiesEvent(context: context));
  }

  void _onRecentActivitiesRefreshButtonPressed() {
    _recentActivitiesBloc.add(LoadRecentActivitiesEvent(context: context));
  }
}

class AddActivityScreenArguments {
  final DateTime day;

  AddActivityScreenArguments({required this.day});
}
