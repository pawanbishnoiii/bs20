# Study Buddy Hub

https://github.com/pawanbishnoiii/learn-flow-buddy-95 complete repo clone kro and database vagera sab add kro and esmme app_events , app_settings , avatar_presets , device_tokens , email_settings , jobs , motivations , notifications , profiles , session_breaks, sessions , study_sessions , subjects , targets , timetable_blocks , user_roles , user_settings , user_xp ( ye user ki strek hogi snapchat me jese hoti hai ) ye sari database ki tables hai and complete clone chahiye fully working and

This project was built with [Lovable](https://lovable.dev).

**Live app**: https://bnoy-study-1.lovable.app

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/c389b4d0-0dce-4870-b721-67a761a56f30).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```

## Google OAuth on Vercel

External deployments start Google OAuth through Supabase (Lovable's `/~oauth` proxy only exists on Lovable hosts).
Configure both sides before deploying:

1. In **Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client**, add this exact authorised redirect URI, replacing the host with `VITE_SUPABASE_URL`:
   `https://<project-ref>.supabase.co/auth/v1/callback`
2. In **Supabase Dashboard → Authentication → URL Configuration**, set the site URL to the production origin and add:
   `https://bs111.vercel.app/auth`
3. In Vercel, define `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` for Production and Preview and redeploy.

The Google authorised redirect URI is the Supabase callback above—not the Vercel page URL.
