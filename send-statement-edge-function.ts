// Supabase Edge Function: send-statement
// Paste this into the Supabase Dashboard's Edge Function editor
// (Edge Functions → Deploy a new function → Via Editor).
//
// This function receives a PDF (as base64) from the app and emails it
// using Resend (https://resend.com). It runs server-side, so your Resend
// API key never appears in the app's source code.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, fromName, subject, html, attachmentBase64, attachmentName } = await req.json();

    if (!to || (Array.isArray(to) && to.length === 0) || !attachmentBase64 || !attachmentName) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cleanUp = (v: string | undefined) => (v || "").replace(/[^\x20-\x7E]/g, "").trim();
    const RESEND_API_KEY = cleanUp(Deno.env.get("RESEND_API_KEY"));
    const FROM_EMAIL = cleanUp(Deno.env.get("FROM_EMAIL")) || "onboarding@resend.dev";

    if (!RESEND_API_KEY) {
      return new Response(JSON.stringify({ error: "RESEND_API_KEY secret is not set" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const toList = Array.isArray(to) ? to.filter(Boolean) : [to];
    if (toList.length === 0) {
      return new Response(JSON.stringify({ error: "No valid recipient addresses" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const cleanFromName = (fromName || "").replace(/[<>"\r\n]/g, "").trim();
    const fromField = cleanFromName ? `${cleanFromName} <${FROM_EMAIL}>` : FROM_EMAIL;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromField,
        to: toList,
        subject,
        html,
        attachments: [{ filename: attachmentName, content: attachmentBase64 }],
      }),
    });

    const data = await resendRes.json();

    if (!resendRes.ok) {
      return new Response(JSON.stringify({ error: data }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, id: data.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
