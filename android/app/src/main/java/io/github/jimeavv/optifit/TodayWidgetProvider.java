package io.github.jimeavv.optifit;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

import es.antonborri.home_widget.HomeWidgetLaunchIntent;
import es.antonborri.home_widget.HomeWidgetProvider;

/**
 * Home-screen widget with today's calories, water and logging streak. The
 * app writes the text (already translated) through the home_widget plugin;
 * see lib/services/home_widget_sync.dart. A tap opens the app.
 */
public class TodayWidgetProvider extends HomeWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager,
                         int[] appWidgetIds, SharedPreferences widgetData) {
        for (int id : appWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.today_widget);
            views.setTextViewText(R.id.widget_title,
                    widgetData.getString("title", context.getString(R.string.today_widget_name)));
            views.setTextViewText(R.id.widget_calories,
                    widgetData.getString("calories", context.getString(R.string.today_widget_open)));
            views.setTextViewText(R.id.widget_water, widgetData.getString("water", ""));
            views.setTextViewText(R.id.widget_streak, widgetData.getString("streak", ""));
            views.setOnClickPendingIntent(R.id.widget_root,
                    HomeWidgetLaunchIntent.INSTANCE.getActivity(context, MainActivity.class, null));
            appWidgetManager.updateAppWidget(id, views);
        }
    }
}
