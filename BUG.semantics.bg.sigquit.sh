# id:4bcabb9a-5684-98ee-e7ae-e162c985be0d@gigawatt.nl
# Harald van Dijk <harald@gigawatt.nl> (2021-01-08) (list)
# Subject: Re: [v3 PATCH 17/17] eval: Add vfork support
# To: Herbert Xu <herbert@gondor.apana.org.au>, DASH Mailing List <dash@vger.kernel.org>
# Date: Fri, 08 Jan 2021 20:55:41 +0000

smoosh -i -c 'smoosh -c "kill -QUIT $$; echo huh" & wait'
