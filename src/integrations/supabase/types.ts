export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      ai_messages: {
        Row: {
          content: string
          created_at: string
          id: string
          metadata: Json
          role: string
          user_id: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          metadata?: Json
          role?: string
          user_id: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          metadata?: Json
          role?: string
          user_id?: string
        }
        Relationships: []
      }
      app_events: {
        Row: {
          created_at: string
          event: string
          id: string
          metadata: Json
          path: string | null
          platform: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string
          event: string
          id?: string
          metadata?: Json
          path?: string | null
          platform?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string
          event?: string
          id?: string
          metadata?: Json
          path?: string | null
          platform?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          id: string
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          id?: string
          key: string
          updated_at?: string
          value?: Json
        }
        Update: {
          id?: string
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      avatar_presets: {
        Row: {
          created_at: string
          id: string
          image_url: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          image_url: string
          is_active?: boolean
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      chapter_learning_state: {
        Row: {
          chapter_name: string
          class_minutes: number
          created_at: string
          id: string
          last_studied_at: string | null
          next_review_at: string
          practice_minutes: number
          reading_minutes: number
          review_stage: number
          revision_minutes: number
          subject_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          chapter_name: string
          class_minutes?: number
          created_at?: string
          id?: string
          last_studied_at?: string | null
          next_review_at?: string
          practice_minutes?: number
          reading_minutes?: number
          review_stage?: number
          revision_minutes?: number
          subject_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          chapter_name?: string
          class_minutes?: number
          created_at?: string
          id?: string
          last_studied_at?: string | null
          next_review_at?: string
          practice_minutes?: number
          reading_minutes?: number
          review_stage?: number
          revision_minutes?: number
          subject_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chapter_learning_state_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      device_tokens: {
        Row: {
          created_at: string
          device_label: string | null
          id: string
          last_seen_at: string | null
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          device_label?: string | null
          id?: string
          last_seen_at?: string | null
          platform?: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          device_label?: string | null
          id?: string
          last_seen_at?: string | null
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      email_settings: {
        Row: {
          enabled: boolean
          from_email: string | null
          from_name: string | null
          id: string
          provider: string
          updated_at: string
        }
        Insert: {
          enabled?: boolean
          from_email?: string | null
          from_name?: string | null
          id?: string
          provider?: string
          updated_at?: string
        }
        Update: {
          enabled?: boolean
          from_email?: string | null
          from_name?: string | null
          id?: string
          provider?: string
          updated_at?: string
        }
        Relationships: []
      }
      jobs: {
        Row: {
          created_at: string
          error: string | null
          finished_at: string | null
          id: string
          name: string
          payload: Json
          run_at: string
          started_at: string | null
          status: string
        }
        Insert: {
          created_at?: string
          error?: string | null
          finished_at?: string | null
          id?: string
          name: string
          payload?: Json
          run_at?: string
          started_at?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          error?: string | null
          finished_at?: string | null
          id?: string
          name?: string
          payload?: Json
          run_at?: string
          started_at?: string | null
          status?: string
        }
        Relationships: []
      }
      motivations: {
        Row: {
          author: string | null
          created_at: string
          id: string
          is_active: boolean
          language: string
          text: string
        }
        Insert: {
          author?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          language?: string
          text: string
        }
        Update: {
          author?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          language?: string
          text?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          action_path: string | null
          audience: string
          body: string | null
          created_at: string
          created_by: string | null
          id: string
          image_url: string | null
          kind: string
          push_sent: boolean
          read: boolean
          title: string
          user_id: string
        }
        Insert: {
          action_path?: string | null
          audience?: string
          body?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          image_url?: string | null
          kind?: string
          push_sent?: boolean
          read?: boolean
          title: string
          user_id: string
        }
        Update: {
          action_path?: string | null
          audience?: string
          body?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          image_url?: string | null
          kind?: string
          push_sent?: boolean
          read?: boolean
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          age: number | null
          avatar_url: string | null
          avg_study_hours: number | null
          bio: string | null
          created_at: string
          display_name: string | null
          email: string | null
          first_name: string | null
          gender: string | null
          id: string
          last_name: string | null
          last_seen_at: string | null
          onboarded: boolean
          onboarded_at: string | null
          phone: string | null
          sign_in_count: number
          timezone: string
          updated_at: string
        }
        Insert: {
          age?: number | null
          avatar_url?: string | null
          avg_study_hours?: number | null
          bio?: string | null
          created_at?: string
          display_name?: string | null
          email?: string | null
          first_name?: string | null
          gender?: string | null
          id: string
          last_name?: string | null
          last_seen_at?: string | null
          onboarded?: boolean
          onboarded_at?: string | null
          phone?: string | null
          sign_in_count?: number
          timezone?: string
          updated_at?: string
        }
        Update: {
          age?: number | null
          avatar_url?: string | null
          avg_study_hours?: number | null
          bio?: string | null
          created_at?: string
          display_name?: string | null
          email?: string | null
          first_name?: string | null
          gender?: string | null
          id?: string
          last_name?: string | null
          last_seen_at?: string | null
          onboarded?: boolean
          onboarded_at?: string | null
          phone?: string | null
          sign_in_count?: number
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      reading_checkins: {
        Row: {
          created_at: string
          id: string
          magazine_done: boolean
          magazine_minutes: number
          magazine_target_minutes: number
          newspaper_done: boolean
          newspaper_minutes: number
          newspaper_target_minutes: number
          reading_date: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          magazine_done?: boolean
          magazine_minutes?: number
          magazine_target_minutes?: number
          newspaper_done?: boolean
          newspaper_minutes?: number
          newspaper_target_minutes?: number
          reading_date?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          magazine_done?: boolean
          magazine_minutes?: number
          magazine_target_minutes?: number
          newspaper_done?: boolean
          newspaper_minutes?: number
          newspaper_target_minutes?: number
          reading_date?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      reading_goals: {
        Row: {
          created_at: string
          magazine_monthly_minutes: number
          newspaper_daily_minutes: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          magazine_monthly_minutes?: number
          newspaper_daily_minutes?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          magazine_monthly_minutes?: number
          newspaper_daily_minutes?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      reading_logs: {
        Row: {
          created_at: string
          id: string
          kind: string
          log_date: string
          minutes: number
          note: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          kind: string
          log_date?: string
          minutes?: number
          note?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          kind?: string
          log_date?: string
          minutes?: number
          note?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      scheduled_notifications: {
        Row: {
          action_path: string | null
          audience: string
          body: string | null
          created_at: string
          created_by: string | null
          id: string
          image_url: string | null
          kind: string
          scheduled_for: string
          sent_at: string | null
          title: string
        }
        Insert: {
          action_path?: string | null
          audience?: string
          body?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          image_url?: string | null
          kind?: string
          scheduled_for: string
          sent_at?: string | null
          title: string
        }
        Update: {
          action_path?: string | null
          audience?: string
          body?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          image_url?: string | null
          kind?: string
          scheduled_for?: string
          sent_at?: string | null
          title?: string
        }
        Relationships: []
      }
      session_breaks: {
        Row: {
          created_at: string
          duration_minutes: number | null
          ended_at: string | null
          id: string
          kind: string
          note: string | null
          session_id: string | null
          started_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          duration_minutes?: number | null
          ended_at?: string | null
          id?: string
          kind?: string
          note?: string | null
          session_id?: string | null
          started_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          duration_minutes?: number | null
          ended_at?: string | null
          id?: string
          kind?: string
          note?: string | null
          session_id?: string | null
          started_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_breaks_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "study_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          created_at: string
          duration_minutes: number | null
          ended_at: string | null
          id: string
          kind: string
          notes: string | null
          started_at: string
          subject_id: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          duration_minutes?: number | null
          ended_at?: string | null
          id?: string
          kind?: string
          notes?: string | null
          started_at?: string
          subject_id?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          duration_minutes?: number | null
          ended_at?: string | null
          id?: string
          kind?: string
          notes?: string | null
          started_at?: string
          subject_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sessions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      study_sessions: {
        Row: {
          auto_closed: boolean
          break_minutes: number
          break_started_at: string | null
          break_type: string | null
          category: string | null
          chapter: string | null
          created_at: string
          duration_minutes: number | null
          duration_seconds: number | null
          ended_at: string | null
          id: string
          is_running: boolean
          kind: string
          notes: string | null
          planned_end_at: string | null
          started_at: string
          subject_id: string | null
          subject_name: string | null
          topic: string | null
          total_break_seconds: number
          user_id: string
          xp_earned: number
        }
        Insert: {
          auto_closed?: boolean
          break_minutes?: number
          break_started_at?: string | null
          break_type?: string | null
          category?: string | null
          chapter?: string | null
          created_at?: string
          duration_minutes?: number | null
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          is_running?: boolean
          kind?: string
          notes?: string | null
          planned_end_at?: string | null
          started_at?: string
          subject_id?: string | null
          subject_name?: string | null
          topic?: string | null
          total_break_seconds?: number
          user_id: string
          xp_earned?: number
        }
        Update: {
          auto_closed?: boolean
          break_minutes?: number
          break_started_at?: string | null
          break_type?: string | null
          category?: string | null
          chapter?: string | null
          created_at?: string
          duration_minutes?: number | null
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          is_running?: boolean
          kind?: string
          notes?: string | null
          planned_end_at?: string | null
          started_at?: string
          subject_id?: string | null
          subject_name?: string | null
          topic?: string | null
          total_break_seconds?: number
          user_id?: string
          xp_earned?: number
        }
        Relationships: [
          {
            foreignKeyName: "study_sessions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      subject_catalog: {
        Row: {
          chapters: Json
          color: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          notes: string | null
          sort_order: number
          stream: string
          updated_at: string
        }
        Insert: {
          chapters?: Json
          color?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          notes?: string | null
          sort_order?: number
          stream?: string
          updated_at?: string
        }
        Update: {
          chapters?: Json
          color?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          notes?: string | null
          sort_order?: number
          stream?: string
          updated_at?: string
        }
        Relationships: []
      }
      subjects: {
        Row: {
          chapters: Json
          color: string
          created_at: string
          id: string
          name: string
          user_id: string
          weekly_target_hours: number
        }
        Insert: {
          chapters?: Json
          color?: string
          created_at?: string
          id?: string
          name: string
          user_id: string
          weekly_target_hours?: number
        }
        Update: {
          chapters?: Json
          color?: string
          created_at?: string
          id?: string
          name?: string
          user_id?: string
          weekly_target_hours?: number
        }
        Relationships: []
      }
      targets: {
        Row: {
          chapters: Json
          created_at: string
          daily_hours: number
          deadline: string | null
          id: string
          is_active: boolean
          subject_id: string | null
          title: string
          user_id: string
          weekly_hours: number
        }
        Insert: {
          chapters?: Json
          created_at?: string
          daily_hours?: number
          deadline?: string | null
          id?: string
          is_active?: boolean
          subject_id?: string | null
          title: string
          user_id: string
          weekly_hours?: number
        }
        Update: {
          chapters?: Json
          created_at?: string
          daily_hours?: number
          deadline?: string | null
          id?: string
          is_active?: boolean
          subject_id?: string | null
          title?: string
          user_id?: string
          weekly_hours?: number
        }
        Relationships: [
          {
            foreignKeyName: "targets_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      timetable_blocks: {
        Row: {
          created_at: string
          day_of_week: number
          end_time: string
          id: string
          kind: string
          location: string | null
          sort_order: number
          start_time: string
          subject_id: string | null
          title: string
          user_id: string
          week_parity: string
        }
        Insert: {
          created_at?: string
          day_of_week: number
          end_time: string
          id?: string
          kind?: string
          location?: string | null
          sort_order?: number
          start_time: string
          subject_id?: string | null
          title: string
          user_id: string
          week_parity?: string
        }
        Update: {
          created_at?: string
          day_of_week?: number
          end_time?: string
          id?: string
          kind?: string
          location?: string | null
          sort_order?: number
          start_time?: string
          subject_id?: string | null
          title?: string
          user_id?: string
          week_parity?: string
        }
        Relationships: [
          {
            foreignKeyName: "timetable_blocks_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_settings: {
        Row: {
          ai_autopilot: boolean
          ai_tone: string
          auto_stop_hours: number
          daily_goal_hours: number
          updated_at: string
          user_id: string
          week_starts_monday: boolean
          weekly_goal_hours: number
        }
        Insert: {
          ai_autopilot?: boolean
          ai_tone?: string
          auto_stop_hours?: number
          daily_goal_hours?: number
          updated_at?: string
          user_id: string
          week_starts_monday?: boolean
          weekly_goal_hours?: number
        }
        Update: {
          ai_autopilot?: boolean
          ai_tone?: string
          auto_stop_hours?: number
          daily_goal_hours?: number
          updated_at?: string
          user_id?: string
          week_starts_monday?: boolean
          weekly_goal_hours?: number
        }
        Relationships: []
      }
      user_xp: {
        Row: {
          id: string
          level: number
          streak: number
          total_xp: number
          updated_at: string
          user_id: string
        }
        Insert: {
          id?: string
          level?: number
          streak?: number
          total_xp?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          id?: string
          level?: number
          streak?: number
          total_xp?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      auto_schedule_targets: { Args: never; Returns: number }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      log_reading: {
        Args: { _kind: string; _minutes: number }
        Returns: {
          created_at: string
          id: string
          kind: string
          log_date: string
          minutes: number
          note: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "reading_logs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      undo_reading: { Args: { _kind: string }; Returns: undefined }
      user_local_date: { Args: { _user_id: string }; Returns: string }
    }
    Enums: {
      app_role: "admin" | "moderator" | "user"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "moderator", "user"],
    },
  },
} as const
