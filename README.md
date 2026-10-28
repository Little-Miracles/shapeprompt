# ShapePrompt

Turn a photo or an idea into a real 3D print. AI clarifies and sketches, the
code calculates a fair price, PayPal handles the payment, the maker makes the
real thing.

Built for the PayPal AI Hackathon on Devpost.

- Scope: [devpost/scope.md](devpost/scope.md)
- Build log: [devpost/build-log.md](devpost/build-log.md)

## AI and keys — demo vs. production

- The dragon's brain is **Google Gemini**, called only from our Cloudflare
  Worker (`worker/`). The key lives there as an encrypted secret; the website
  never sees it. Cloudflare Turnstile lets only real people talk to the
  dragon, and each address has a request limit.
- **For this demo the Gemini API runs on the free tier.** It has a daily
  limit: when it is used up, the dragon says kindly to try again a little
  later.
- **For real sales we switch to the paid tier.** Gemini's terms allow only
  the paid tier for apps used by people in the EU, and on the paid tier the
  customers' messages and pictures are not used to train Google's models.
- AI never sets a price: prices come from the maker's own numbers in code
  (`lib/pricing.dart`, exported to `worker/src/catalog.json`), and the
  Worker prices every order again before PayPal sees it.

## Run locally

```
flutter pub get
flutter run -d chrome
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
