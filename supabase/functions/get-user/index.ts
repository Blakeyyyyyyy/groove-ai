// Supabase Edge Function: get-user
// Fetch user profile, coins, subscription status
// Deploy: supabase functions deploy get-user --project-ref tfbcdcrlhsxvlufmnzdr

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get auth user from JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch or create user record
    let { data: userData, error: fetchError } = await supabase
      .from("users")
      .select("*")
      .eq("id", user.id)
      .single();

    if (fetchError && fetchError.code === "PGRST116") {
      // User doesn't exist — create
      const { data: newUser, error: insertError } = await supabase
        .from("users")
        .insert({
          id: user.id,
          coins: 150,
          subscription_status: "free",
          r2_user_folder: `users/${user.id}/`,
        })
        .select()
        .single();

      if (insertError) {
        throw insertError;
      }
      userData = newUser;
    } else if (fetchError) {
      throw fetchError;
    }

    // Lazy expiry check: if the cached expiry has passed and the row is still
    // marked subscribed (e.g. the EXPIRATION webhook hasn't arrived yet, or
    // RevenueCat is delayed), demote the user inline so the client gets the
    // correct status on its next get-user call. This is now real code — the
    // revenuecat-webhook function populates subscription_expires_at on
    // INITIAL_PURCHASE / RENEWAL / CANCELLATION events.
    if (
      userData.subscription_status !== "free" &&
      userData.subscription_expires_at &&
      new Date(userData.subscription_expires_at) < new Date()
    ) {
      await supabase
        .from("users")
        .update({
          subscription_status: "free",
          subscription_expires_at: null,
        })
        .eq("id", user.id);
      userData.subscription_status = "free";
      userData.subscription_expires_at = null;
    }

    return new Response(JSON.stringify({ user: userData }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
